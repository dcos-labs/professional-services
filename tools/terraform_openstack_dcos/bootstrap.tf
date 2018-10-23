resource "openstack_compute_instance_v2" "dcos_bootstrap_node" {
  # make sure the network is really available, so the metadata server can be reached (e.g. for cloud-init)
  depends_on = ["openstack_networking_router_interface_v2.dcos_router_interface"]

  name            = "dcos_bootstrap_node"
  image_name      = "${var.image}"
  flavor_name     = "${var.bootstrap_flavor}"
  key_pair        = "${var.ssh_key_name}"

  network {
    uuid = "${openstack_networking_network_v2.dcos_network.id}"
  }

  security_groups = ["${openstack_networking_secgroup_v2.ssh.id}", "${openstack_networking_secgroup_v2.any_access_internal.id}"]
}

# public floating IPs for Private Agents are merely for more convenient Ansible Install and should not be default (at least not after install)
resource "openstack_compute_floatingip_v2" "dcos_bootstrap_node_floating_ip" {
  pool       = "${var.pool}"
  depends_on = ["openstack_networking_router_interface_v2.dcos_router_interface"]
}

resource "openstack_compute_floatingip_associate_v2" "dcos_bootstrap_floating_ip_mapping" {
  floating_ip = "${openstack_compute_floatingip_v2.dcos_bootstrap_node_floating_ip.address}"
  instance_id = "${openstack_compute_instance_v2.dcos_bootstrap_node.id}"

  connection {
    user = "${var.ssh_user_name}"
    private_key = "${local.private_key}"
    agent = "${local.agent}"
    host = "${openstack_compute_floatingip_v2.dcos_bootstrap_node_floating_ip.address}"
  }

  provisioner "file" {
   source = "${var.os_setup_script_file}"
   destination = "/tmp/os-setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/os-setup.sh",
      "sudo bash /tmp/os-setup.sh",
    ]
  }
}
