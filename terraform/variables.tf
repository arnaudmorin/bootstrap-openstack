variable "name" {
  description = "name of openstack project"
  default     = "myopenstack"
}

variable "attach_vrack" {
  description = "Determines if vrack has to be attach to the openstack project"
  default     = false
}

variable "project_id" {
  description = "The id of the cloud project"
}

variable "vrack_id" {
  description = "The id of the vrack"
}

variable "public_subnet" {
  description = "The subnet for the public network per region"
  default     = "10.0.0.0/24"
}

variable "mgmt_vlan_id" {
  description = "The id of mgmt vlan"
  default     = "192"
}

variable "mgmt_subnet" {
  description = "The subnet for the management network per region"
  default     = "192.168.1.0/24"
}

variable "region" {
  description = "The target openstack region"
  default     = "GRA3"
}

variable "os_version" {
  description = "the version of openstack to deploy"
  default     = "pike"
}

variable "ssh_public_key" {
  description = "The path of the ssh public key that will be used by ansible to provision the hosts"
  default     = "~/.ssh/id_rsa.pub"
}

variable "flavor_name" {
  description = "The flavor name used for the hosts"
  default     = "c2-7"
}

variable "nodes" {
  description = "the list of node names to boot. will be used as roles by ansible"
  type        = "list"

  default = [
    "rabbit",
    "mysql",
    "keystone",
    "glance",
    "neutron",
    "nova",
    "horizon",
    "compute-1",
  ]
}

variable "password" {
  description = "the password used for all subsystem of openstack"
  default     = "zoblesmouches42"
}
