resource "openstack_networking_network_v2" "dcos_network" {
  name           = "dcos_network"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "dcos_subnet" {
  name            = "dcos_subnet"
  network_id      = "${openstack_networking_network_v2.dcos_network.id}"
  cidr            = "192.168.100.0/24"
  ip_version      = 4
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
}

resource "openstack_networking_router_v2" "dcos_router" {
  name             = "dcos_router"
  admin_state_up   = "true"
  external_network_id = "${var.external_gateway}"
}

resource "openstack_networking_router_interface_v2" "dcos_router_interface" {
  router_id = "${openstack_networking_router_v2.dcos_router.id}"
  subnet_id = "${openstack_networking_subnet_v2.dcos_subnet.id}"
}

# use neutron security groups instead of old nova security groups (openstack_compute_secgroup_v2 vs openstack_networking_secgroup_v2)
# SSH access for all nodes
resource "openstack_networking_secgroup_v2" "ssh" {
  name = "ssh"
  description = "Security group for SSH access (e.g. for Terraform)"
}

resource "openstack_networking_secgroup_rule_v2" "ssh_rule" {
  direction = "ingress"
  ethertype = "IPv4"
  port_range_min = 22
  port_range_max = 22
  protocol = "tcp"
  # source IP (range) might be further locked down
  remote_ip_prefix = "0.0.0.0/0"

  security_group_id = "${openstack_networking_secgroup_v2.ssh.id}"
}

# HTTPS access for strict mode master
resource "openstack_networking_secgroup_v2" "https" {
  name = "https"
  description = "Security group Master Web Interface + API"
}

resource "openstack_networking_secgroup_rule_v2" "https_rule" {
  direction = "ingress"
  ethertype = "IPv4"
  port_range_min = 443
  port_range_max = 443
  protocol = "tcp"
  # source IP (range) might be further locked down
  remote_ip_prefix = "0.0.0.0/0"

  security_group_id = "${openstack_networking_secgroup_v2.https.id}"
}

# a security group just for the public agents that wants to expose a lot via TCP
resource "openstack_networking_secgroup_v2" "all_tcp_open" {
  name = "completely_open"
  description = "Security group for Public Agent"
}

resource "openstack_networking_secgroup_rule_v2" "all_tcp_open_rule" {
  direction = "ingress"
  ethertype = "IPv4"
  port_range_min = 1
  port_range_max = 65535
  protocol = "tcp"
  # source IP (range) might be further locked down
  remote_ip_prefix = "0.0.0.0/0"

  security_group_id = "${openstack_networking_secgroup_v2.all_tcp_open.id}"
}

# A security group that allows all port inside the cluster
resource "openstack_networking_secgroup_v2" "any_access_internal" {
  name = "any_access_internal"
  description = "Security group for cluster (+bootstrap) internal communication"
}

resource "openstack_networking_secgroup_rule_v2" "IPv4_any_access" {
  direction = "ingress"
  ethertype = "IPv4"
  remote_ip_prefix = "${openstack_networking_subnet_v2.dcos_subnet.cidr}"

  security_group_id = "${openstack_networking_secgroup_v2.any_access_internal.id}"
}

