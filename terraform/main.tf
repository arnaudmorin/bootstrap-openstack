provider "ovh" {
  endpoint = "ovh-eu"
}

provider "openstack" {
  version     = "~> 1.2"
  user_name   = "${ovh_publiccloud_user.openstack.username}"
  password    = "${ovh_publiccloud_user.openstack.password}"
  tenant_name = "${lookup(ovh_publiccloud_user.openstack.openstack_rc, "OS_TENANT_NAME")}"
  auth_url    = "${lookup(ovh_publiccloud_user.openstack.openstack_rc, "OS_AUTH_URL")}"
  region      = "${var.region}"
}

resource "ovh_vrack_publiccloud_attachment" "attach_vrack" {
  count      = "${var.attach_vrack ? 1 : 0}"
  vrack_id   = "${var.vrack_id}"
  project_id = "${var.project_id}"
}

resource "ovh_publiccloud_user" "openstack" {
  project_id  = "${var.project_id}"
  description = "The openstack user used to bootstrap openstack on openstack"
}

resource "ovh_publiccloud_private_network" "public" {
  project_id = "${var.project_id}"
  name       = "${var.name}_public"
  regions    = ["${var.region}"]
  vlan_id    = 0

  depends_on = ["ovh_vrack_publiccloud_attachment.attach_vrack"]
}

resource "ovh_publiccloud_private_network_subnet" "public_subnet" {
  project_id = "${var.project_id}"
  network_id = "${ovh_publiccloud_private_network.public.id}"
  region     = "${var.region}"
  start      = "${cidrhost(var.public_subnet, 1)}"
  end        = "${cidrhost(var.public_subnet, -2)}"
  network    = "${var.public_subnet}"
  dhcp       = false
  no_gateway = true
}

resource "openstack_networking_network_v2" "mgmt" {
  name           = "${var.name}_management"
  admin_state_up = "true"
  depends_on     = ["ovh_publiccloud_user.openstack"]
}

resource "openstack_networking_subnet_v2" "public_subnets" {
  name        = "${var.name}_mgmt_subnet"
  network_id  = "${openstack_networking_network_v2.mgmt.id}"
  cidr        = "${var.mgmt_subnet}"
  ip_version  = 4
  enable_dhcp = true
  no_gateway  = true
  depends_on  = ["ovh_publiccloud_user.openstack"]
}

resource "openstack_compute_keypair_v2" "keypair" {
  name       = "${var.name}_deploy"
  public_key = "${file(var.ssh_public_key)}"
  depends_on = ["ovh_publiccloud_user.openstack"]
}

resource "tls_private_key" "deployer" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
  depends_on  = ["ovh_publiccloud_user.openstack"]
}

data "template_file" "systemd_network_files" {
  template = <<TPL
- path: /etc/systemd/network/10-ens3.network
  permissions: '0644'
  content: |
    [Match]
    Name=ens3
    [Network]
    DHCP=ipv4
- path: /etc/systemd/network/20-ens4.network
  permissions: '0644'
  content: |
    [Match]
    Name=ens4
    [Network]
    DHCP=ipv4
- path: /etc/systemd/network/30-ens5.network
  permissions: '0644'
  content: |
    [Match]
    Name=ens5
    [Network]
    DHCP=no
    [Link]
    MTUBytes=9000
TPL
}

data "template_file" "nodes" {
  template = <<CLOUDCONFIG
#cloud-config
ssh_authorized_keys:
   - ${tls_private_key.deployer.public_key_openssh}
write_files:
  ${indent(2, data.template_file.systemd_network_files.rendered)}
runcmd:
  # required at first boot to enable all netif
  - systemctl restart systemd-networkd
CLOUDCONFIG
}

# get NATed IP to allow ssh only from terraform host
data "http" "myip" {
  url = "https://api.ipify.org"
}

# create the security group to which the instances & pub ports will be associated
resource "openstack_networking_secgroup_v2" "pubsg" {
  name        = "${var.name}_pub_sg"
  description = "${var.name} security group"
}

# create the security group to which the instances & mgmt ports will be associated
resource "openstack_networking_secgroup_v2" "mgmtsg" {
  name        = "${var.name}_mgmt_sg"
  description = "${var.name} security group"
}

# create the security group to which the instances & extnet ports will be associated
resource "openstack_networking_secgroup_v2" "extsg" {
  name        = "${var.name}_ext_sg"
  description = "${var.name} security group"
}

# allow remote ssh connection only for terraform host
resource "openstack_networking_secgroup_rule_v2" "in_traffic_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  remote_ip_prefix  = "${trimspace(data.http.myip.body)}/32"
  port_range_min    = 22
  port_range_max    = 22
  security_group_id = "${openstack_networking_secgroup_v2.extsg.id}"
}

# allow ingress traffic inter instances
resource "openstack_networking_secgroup_rule_v2" "ingress_instances" {
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_group_id   = "${openstack_networking_secgroup_v2.extsg.id}"
  security_group_id = "${openstack_networking_secgroup_v2.extsg.id}"
}

# allow egress traffic worldwide
resource "openstack_networking_secgroup_rule_v2" "egress_instances" {
  direction         = "egress"
  ethertype         = "IPv4"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.extsg.id}"
}

data "openstack_networking_network_v2" "ext_net" {
  name      = "Ext-Net"
  tenant_id = ""
}

resource "openstack_networking_port_v2" "ssh" {
  count          = "${length(var.nodes)}"
  name           = "${var.name}_${element(var.nodes, count.index)}_ssh"
  network_id     = "${data.openstack_networking_network_v2.ext_net.id}"
  admin_state_up = "true"

  # the security groups are attached to the ports, not the instance.
  security_group_ids = ["${openstack_networking_secgroup_v2.extsg.id}"]

  depends_on     = ["ovh_publiccloud_user.openstack"]
}

data "openstack_networking_network_v2" "public" {
  name = "${ovh_publiccloud_private_network.public.name}"
}

resource "openstack_networking_port_v2" "public" {
  count          = "${length(var.nodes)}"
  name           = "${var.name}_${element(var.nodes, count.index)}_ssh"
  network_id     = "${data.openstack_networking_network_v2.public.id}"
  admin_state_up = "true"

  # the security groups are attached to the ports, not the instance.
  security_group_ids = ["${openstack_networking_secgroup_v2.pubsg.id}"]

  depends_on     = ["ovh_publiccloud_user.openstack"]
}

resource "openstack_networking_port_v2" "mgmt" {
  count          = "${length(var.nodes)}"
  name           = "${var.name}_${element(var.nodes, count.index)}_mgmt"
  network_id     = "${openstack_networking_network_v2.mgmt.id}"
  admin_state_up = "true"

  # the security groups are attached to the ports, not the instance.
  security_group_ids = ["${openstack_networking_secgroup_v2.mgmtsg.id}"]

  depends_on     = ["ovh_publiccloud_user.openstack"]
}

resource "openstack_compute_instance_v2" "nodes" {
  count       = "${length(var.nodes)}"
  name        = "${var.name}_${element(var.nodes, count.index)}"
  image_name  = "Ubuntu 18.04"
  flavor_name = "${var.flavor_name}"
  key_pair    = "${openstack_compute_keypair_v2.keypair.name}"
  user_data   = "${data.template_file.nodes.rendered}"

  # Configure network
  # ens3 --> Ext-Net interface. Mostly used to access API over regular internet connection
  # ens4 --> management interface. Mostly used by some OpenStack services to communicate
  # ens5 --> public interface. Used by neutron and compute to handle VM <--> Internet connectivity
  network {
    access_network = true
    port           = "${openstack_networking_port_v2.ssh.*.id[count.index]}"
  }

  network {
    port           = "${openstack_networking_port_v2.mgmt.*.id[count.index]}"
  }

  network {
    port           = "${openstack_networking_port_v2.public.*.id[count.index]}"
  }
}

data "template_file" "inventory_host" {
  count = "${length(var.nodes)}"

  template = <<INV
[${element(var.nodes, count.index)}]
${element(var.nodes, count.index)} ansible_ssh_host=${element(flatten(openstack_networking_port_v2.mgmt.*.all_fixed_ips), count.index)} ansible_host=${element(flatten(openstack_networking_port_v2.mgmt.*.all_fixed_ips), count.index)} public_ip=${element(openstack_compute_instance_v2.nodes.*.access_ip_v4, count.index)}
INV
}

data "template_file" "deployer" {
  template = <<CLOUDCONFIG
#cloud-config
network:
    version: 2
    ethernets:
        ens3:
            dhcp4: true
            set-name: ens3
        ens4:
            dhcp4: true
            set-name: ens4
ssh_keys:
   ecdsa_private: |
      ${indent(6,tls_private_key.deployer.private_key_pem)}
   ecdsa_public: ${tls_private_key.deployer.public_key_openssh}
write_files:
  ${indent(2, data.template_file.systemd_network_files.rendered)}
  - path: /tmp/inventory
    content: |
      [all:vars]
      password=${var.password}

      ${indent(6,join("\n", data.template_file.inventory_host.*.rendered))}
  - path: /tmp/ssh-priv-key
    permissions: '0600'
    content: |
      ${indent(6,tls_private_key.deployer.private_key_pem)}
runcmd:
  # required at first boot to enable all netif
  - systemctl restart systemd-networkd
CLOUDCONFIG
}

resource "openstack_compute_instance_v2" "deployer" {
  name        = "${var.name}_deployer"
  image_name  = "Ubuntu 18.04"
  flavor_name = "${var.flavor_name}"
  key_pair    = "${openstack_compute_keypair_v2.keypair.name}"
  user_data   = "${data.template_file.deployer.rendered}"

  # Configure network
  # ens3 --> Ext-Net interface. Mostly used to access API over regular internet connection
  # ens4 --> management interface. Mostly used by some OpenStack services to communicate
  network {
    access_network = true
    name           = "Ext-Net"
  }

  network {
    name = "${openstack_networking_network_v2.mgmt.name}"
  }
}

resource "null_resource" "provision" {
  # Changes to any instance of the cluster requires re-provisioning
  triggers {
    nodes_instance_ids = "${join(",", openstack_compute_instance_v2.nodes.*.id)}"
    deployer_id        = "${openstack_compute_instance_v2.deployer.id}"
  }

  connection {
    type = "ssh"
    host = "${openstack_compute_instance_v2.deployer.access_ip_v4}"
    user = "ubuntu"
  }

  provisioner "file" {
    source      = "../ansible"
    destination = "/tmp"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo add-apt-repository -y ppa:ansible/ansible",
      "sudo apt update -y && sudo apt install -y ansible",
      "sudo chown ubuntu:ubuntu /tmp/ssh-priv-key",
      "eval $(ssh-agent) && ssh-add /tmp/ssh-priv-key",
      "export ANSIBLE_HOST_KEY_CHECKING=False",
      "ansible-playbook -e 'ansible_python_interpreter=/usr/bin/python3' -i /tmp/inventory /tmp/ansible/site.yml",
    ]
  }
}


resource "null_resource" "configure" {

  connection {
    type = "ssh"
    host = "${openstack_compute_instance_v2.nodes..access_ip_v4}"
    user = "ubuntu"
  }

  provisioner "remote-exec" {
    inline = [
      # Source helper functions
      "sudo -u keystone",
      "source helper",

      # Following actions are done as admin
      "source openrc_admin",
      "create_flavors",
      "create_image_cirros",
      "create_image_ubuntu",
      # Before running this one, update the function in helper and source it again to ajust with your network settings
      "create_network_public"
    ]
  }
}

