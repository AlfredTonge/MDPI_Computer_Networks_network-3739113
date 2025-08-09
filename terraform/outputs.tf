#output "vps_ips" {
#  value = hcloud_server.vps[*].ipv4_address
#}
#output "vps_regions" {
#  value = hcloud_server.vps[*].location
#}
output "vps_ips_regions" {
  value = zipmap(hcloud_server.k8s_node[*].ipv4_address, hcloud_server.k8s_node[*].name)
}

output "test_server_ips" {
  value = hcloud_server.test_server[*].ipv4_address
}

output "load_balancer_ip" {
  value = hcloud_load_balancer.lb1.ipv4
}