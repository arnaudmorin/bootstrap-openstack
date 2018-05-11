**Table of Contents**

- [Introduction](#introduction)
    - [Objective](#objective)
    - [Architecture](#architecture)
- [Prepare your environment](#prepare-your-environment)
    - [Create your OVH account](#create-your-ovh-account)
    - [Create a cloud project](#create-a-cloud-project)
    - [Activate vRack on your cloud project](#activate-vrack-on-your-cloud-project)
    - [Link your project to this new vRack](#link-your-project-to-this-new-vrack)
    - [Create ovhrc file](#create-ovhrc-file)
    - [Order a /28 failover IP block](#order-a-28-failover-ip-block)
- [Bootstrap](#bootstrap)
    - [Clone this repo](#clone-this-repo)
    - [Install terraform](#install-terraform)
    - [Source openrc file](#source-openrc-file)
    - [Terraform](#terraform)
    - [Ansible](#ansible)
        - [Configure inventory file](#configure-inventory-file)
        - [Playbooks](#playbooks)
        - [Run the playbook](#run-the-playbook)
- [Configure](#configure)
    - [Keystone](#keystone)
    - [Horizon](#horizon)
- [Enjoy](#enjoy)

# Introduction
## Objective

Main objective is to create an small OpenStack infrastructure within an OVH public cloud infrastructure (which is also run by OpenStack by the way :p So we will create an OpenStack over OpenStack).

## Architecture
```
                       +------------------+
              ssh      |                  |
you     +----------->  |     deployer     |
                       |                  |
                       +------------------+

                           ansible (ssh)


+------------------+   +------------------+   +------------------+         +-----+
|                  |   |                  |   |                  |         |     |
|      rabbit      |   |       nova       |   |      neutron     | +-----> |     |
|                  |   |                  |   |                  |         |  v  |
+------------------+   +------------------+   +------------------+         |  R  |
                                                                           |  a  | <--------+ Failover IP
+------------------+   +------------------+   +------------------+         |  c  |            xxx.xxx.xxx.xxx/28
|                  |   |                  |   |                  |         |  k  |
|      mysql       |   |      glance      |   |      compute     | +-----> |     |
|                  |   |                  |   |                  |         |     |
+------------------+   +------------------+   +------------------+         +-----+

+------------------+   +------------------+
|                  |   |                  |
|      horizon     |   |     keystone     |
|                  |   |                  |
+------------------+   +------------------+
```

Every machine will have a public IP and be accessible from internet.

Neutron and compute will also be connected through vRack.

In this vRack we will route a failover IP block (/28 in my example) so that we can give public IPs to instances / routers.

Deployer is used to configure the others (like an admin / jumphost machine).

# Prepare your environment
To start working on this project, you must have:
 - an account on OVH
 - a cloud project
 - a vRack

## Create your OVH account
See here:
https://www.ovh.com/fr/support/new_nic.xml

## Create a cloud project

![Create cloud project](data/create_cloud.gif "Create cloud project")

## Activate vRack on your cloud project

![Enable vRack](data/enable_vrack.gif "Enable vRack")

## Link your project to this new vRack

![Link vRack](data/link_vrack.gif "Link vRack")

## Create ovhrc file

- first register an app on ovh api
  https://eu.api.ovh.com/createApp/
- then get api token
``` bash
curl -XPOST -H"X-Ovh-Application: YOUR_APP_KEY" -H "Content-type: application/json" \
https://eu.api.ovh.com/1.0/auth/credential  -d '{
    "accessRules": [
        { "method": "GET", "path": "/*" },
        { "method": "PUT", "path": "/*" },
        { "method": "POST", "path": "/*" },
        { "method": "DELETE", "path": "/*" }
    ]
}'
{"validationUrl":"https://eu.api.ovh.com/auth/?credentialToken=Am0xPp...","consumerKey":"YOUR_CONSUMER_KEY","state":"pendingValidation"}
```

- create an `ovhrc` file with api creds from json:
``` bash
OVH_ENDPOINT="ovh-eu"
OVH_APPLICATION_KEY="YOUR_APP_KEY"
OVH_APPLICATION_SECRET="YOUR_APP_SECRET"
OVH_CONSUMER_KEY="YOUR_CONSUMER_KEY"
```

## Order a /28 failover IP block

To do that, you can run the script data/order_ip_block.py
```sh
$ python3 order_ip_block.py
Please pay the BC 12345678 --> https://www.ovh.com/cgi-bin/order/displayOrder.cgi?orderId=12345678&orderPassword=ABCD
Done
```

Once your BC (Bon de Commande / order) is paid, you should receive a /28 in your manager. You can now move this pool of IP in your vRack by doing so:
![Add IP in vRack](data/add_ip_vrack.gif "Add IP in vRack")


# Bootstrap
## Clone this repo
```sh
$ git clone https://github.com/arnaudmorin/bootstrap-openstack.git
$ cd bootstrap-openstack
```

## Install terraform

see [Terraform install page](https://www.terraform.io/intro/getting-started/install.html)

## Source openrc file
```sh
$ source ovhrc
```

## Terraform

The terraform script creates an openstack user through the `ovh` provider, then use its credentials
to setup the `openstack` provider. Thus we have to `apply` the terraform script in 3 steps:

```sh
$ terraform init
$ terraform apply -var project_id=123ABC...XX99  -var vrack_id=pn-XXXXXX -target ovh_publiccloud_user.openstack
$ terraform apply -var project_id=123ABC...XX99  -var vrack_id=pn-XXXXXX

```

This will create 8 instances, connected to both public network (Ext-Net) and vRack (public), one for each OpenStack services (see architecture) and one deployer that you will use as jump host / ansible executor.

Once instances are all up and active, terraform will run the ansible playbook on the deployer.

## Ansible
### Configure inventory file
Ansible is using a static inventory file generated by terraform and uploaded through user-data on the deployer instance
in `/tmp/inventory`

### Playbooks
Ansible playbooks are stored in the `./ansible` directory and uploaded on the deployer instance in `/tmp/ansible` through
ssh in a terraform post provisionning action

### Run the playbook

Terraform applies the playbooks by running the following commands

``` bash
eval $(ssh-agent) && ssh-add /tmp/ssh-priv-key
export ANSIBLE_HOST_KEY_CHECKING=False
ansible-playbook -e 'ansible_python_interpreter=/usr/bin/python3' -i /tmp/inventory /tmp/ansible/site.yml
```

Ansible connects to nodes instances by using an ssh keypair generated by terraform, from which the ssh pub key
has been uploaded through user-data to all nodes as an authorized_key.

# Configure

## Keystone
On keystone server, you will find the openrc_admin in `/var/lib/keystone` and openrc_demo in `/home/ubuntu` files that can be used to access your brand new OpenStack infrastructure

## Horizon
You can also browse the dashboard by opening url like this: http://*your_horizon_ip*/horizon/

# Enjoy
