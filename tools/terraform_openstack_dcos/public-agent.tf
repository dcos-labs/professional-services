resource "openstack_compute_instance_v2" "dcos_public_agent" {
  # make sure the network is really available, so the metadata server can be reached (e.g. for cloud-init)
  depends_on = ["openstack_networking_router_interface_v2.dcos_router_interface"]

  name            = "${format("dcos_public_agent-%03d", count.index+1)}"
  image_name      = "${var.image}"
  flavor_name     = "${var.public_agent_flavor}"
  key_pair        = "${var.ssh_key_name}"

  count = "${var.num_of_public_agents}"

  network {
    uuid = "${openstack_networking_network_v2.dcos_network.id}"
  }

  security_groups = ["${openstack_networking_secgroup_v2.ssh.id}", "${openstack_networking_secgroup_v2.any_access_internal.id}","${openstack_networking_secgroup_v2.all_tcp_open.id}"]


}

resource "openstack_compute_floatingip_v2" "dcos_public_agent_floating_ip" {
  pool       = "${var.pool}"
  depends_on = ["openstack_networking_router_interface_v2.dcos_router_interface"]

  count = "${var.num_of_public_agents}"
}

resource "openstack_compute_floatingip_associate_v2" "dcos_public_agent_floating_ip_mapping" {
  count = "${var.num_of_public_agents}"

  floating_ip = "${element(openstack_compute_floatingip_v2.dcos_public_agent_floating_ip.*.address, count.index)}"
  instance_id = "${element(openstack_compute_instance_v2.dcos_public_agent.*.id, count.index)}"


  connection {
    user = "${var.ssh_user_name}"
    private_key = "${local.private_key}"
    agent = "${local.agent}"
    host = "${element(openstack_compute_floatingip_v2.dcos_public_agent_floating_ip.*.address, count.index)}"
  }

  # OS init script
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
