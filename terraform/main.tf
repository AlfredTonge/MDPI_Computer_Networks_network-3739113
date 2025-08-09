resource "hcloud_ssh_key" "default" {
  name       = "hetzner_key"
  public_key = file("~/.ssh/id_ed25519.pub")
}

resource "hcloud_placement_group" "placement-group" {
  name = "placement-group"
  type = "spread"
}

resource "hcloud_server" "k8s_node" {
  count       = var.node_count
  name        = "k8s-${format("%01d", count.index + 1)}.domain.com"
  image       = "debian-12"
  server_type = "cax31"
  location    = "hel1"
  ssh_keys    = [hcloud_ssh_key.default.id]
  network {
    network_id  = hcloud_network.network.id
    ip = "10.0.1.${count.index + 3}"
  }
  depends_on = [
    hcloud_network_subnet.cluster-subnet
  ]
  #placement_group_id = hcloud_placement_group.placement-group.id
  labels = {
    type = "k8s-node"
  }
  user_data = file("../cloud-config/cloud-config.yml")
  connection {
    type      = "ssh"
    user      = "ansible"
    host      = self.ipv4_address
    private_key = "${file("~/.ssh/id_ed25519")}"
  }

  provisioner "remote-exec" {
  inline = [
    "cloud-init status --wait > /dev/null"
    ]
  }
}

resource "hcloud_server" "test_server" {
  count       = 1
  name        = "test-node.domain.com"
  image       = "debian-12"
  server_type = "ccx23"
  location    = "hel1"
  ssh_keys    = [hcloud_ssh_key.default.id]
  network {
    network_id  = hcloud_network.network.id
    ip = "10.0.1.100"
  }
  depends_on = [
    hcloud_network_subnet.cluster-subnet
  ]
  placement_group_id = hcloud_placement_group.placement-group.id
  labels = {
    type = "k8s-node"
  }
  user_data = file("../cloud-config/cloud-config.yml")
  connection {
    type      = "ssh"
    user      = "ansible"
    host      = self.ipv4_address
    private_key = "${file("~/.ssh/id_ed25519")}"
  }

  provisioner "remote-exec" {
  inline = [
    "cloud-init status --wait > /dev/null"
    ]
  }
}

resource "hcloud_firewall" "firewall" {
  name = "firewall"
  rule {
    direction = "in"
    protocol = "tcp"
    port = "22"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
  apply_to {
    label_selector = "type=k8s-node"
  }
  depends_on = [
    hcloud_server.k8s_node
  ]
}

resource "hcloud_network" "network" {
  name     = "network"
  ip_range = "10.0.0.0/8"
}

resource "hcloud_network_subnet" "cluster-subnet" {
  type         = "cloud"
  network_id   = hcloud_network.network.id
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}
resource "hcloud_load_balancer" "lb1" {
  name               = "lb1"
  load_balancer_type = "lb11"
  network_zone       = "eu-central"
}

resource "hcloud_load_balancer_network" "ingresslb" {
  load_balancer_id = hcloud_load_balancer.lb1.id
  network_id       = hcloud_network.network.id
  ip               = "10.0.1.1"
  depends_on = [ hcloud_load_balancer.lb1 ]
}

resource "hcloud_load_balancer_target" "load_balancer_target" {
  type             = "label_selector"
  load_balancer_id = hcloud_load_balancer.lb1.id
  label_selector = "type=k8s-node"
  use_private_ip = true
  depends_on = [ hcloud_load_balancer_network.ingresslb ]
}

# resource "hcloud_load_balancer_service" "load_balancer_service" {
#   load_balancer_id = hcloud_load_balancer.lb1.id
#   protocol         = "tcp"
#   listen_port      = 6443
#   destination_port = 6443
#   proxyprotocol    = true
#   health_check {
#     protocol = "tcp"
#     port     = 6443
#     interval = 10
#     timeout  = 5
#     retries  = 3
#   }
#   depends_on = [ hcloud_load_balancer.lb1 ]
# }

resource "hcloud_load_balancer_service" "load_balancer_service2" {
  load_balancer_id = hcloud_load_balancer.lb1.id
  protocol         = "tcp"
  listen_port      = 80
  destination_port = 80
  proxyprotocol    = false
  health_check {
    protocol = "tcp"
    port     = 80
    interval = 10
    timeout  = 5
    retries  = 3
  }
  depends_on = [ hcloud_load_balancer.lb1 ]
}

resource "hcloud_load_balancer_service" "load_balancer_service3" {
  load_balancer_id = hcloud_load_balancer.lb1.id
  protocol         = "tcp"
  listen_port      = 443
  destination_port = 443
  proxyprotocol    = false
  health_check {
    protocol = "tcp"
    port     = 443
    interval = 10
    timeout  = 5
    retries  = 3
  }
  depends_on = [ hcloud_load_balancer.lb1 ]
}

resource "cloudflare_dns_record" "lb1" {
  zone_id = var.cloudflare_api_zoneid
  name    = "*.fyp.domain.com"
  type    = "A"
  ttl     = 1         # automatic
  content = hcloud_load_balancer.lb1.ipv4
  proxied = false

  depends_on = [
    hcloud_load_balancer_network.ingresslb
  ]
}

resource "local_file" "ansible_inventory" {
  content = <<EOF
[k8s-node]
%{for i in hcloud_server.k8s_node~}
${i.ipv4_address}
%{endfor~}
[test-server]
%{for i in hcloud_server.test_server~}
${i.ipv4_address}
%{endfor~}
EOF
filename = "../ansible/hosts"
}
