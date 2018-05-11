#output "access_ipv4" {
#  value       = "${zipmap(openstack_compute_instance_v2.nodes.*.name, openstack_compute_instance_v2.nodes.*.access_ip_v4)}"
#}

output "deployer_access_ipv4" {
  value       = "${openstack_compute_instance_v2.deployer.access_ip_v4}"
}
