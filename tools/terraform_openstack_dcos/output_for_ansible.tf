# output hosts.yaml for later consumption of Ansible automation scripts
data "template_file" "private_agent_ips" {
  template = "${file("templates/ansible_hosts_block.tpl")}"
  count    = "${var.num_of_private_agents}"

  vars {
    ip = "${element(openstack_compute_floatingip_v2.dcos_private_agent_floating_ip.*.address, count.index)}"
  }
}

data "template_file" "public_agent_ips" {
  template = "${file("templates/ansible_hosts_block.tpl")}"
  count    = "${var.num_of_public_agents}"

  vars {
    ip = "${element(openstack_compute_floatingip_v2.dcos_public_agent_floating_ip.*.address, count.index)}"
  }
}

data "template_file" "master_ips" {
  template = "${file("templates/ansible_hosts_block.tpl")}"
  count    = "${var.num_of_masters}"

  vars {
    ip = "${element(openstack_compute_floatingip_v2.dcos_master_floating_ip.*.address, count.index)}"
  }
}


data "template_file" "ansible_inventory" {
  template = "${file("templates/ansible_inventory_yaml.tpl")}"

  vars {
    bootstrap_node_public_ip="${openstack_compute_floatingip_v2.dcos_bootstrap_node_floating_ip.address}"
    bootstrap_node_internal_ip="${openstack_compute_instance_v2.dcos_bootstrap_node.access_ip_v4}"

    private_agent_node_ip_block="${join("\n", data.template_file.private_agent_ips.*.rendered)}"
    public_agent_node_ip_block="${join("\n", data.template_file.public_agent_ips.*.rendered)}"
    master_node_ip_block="${join("\n", data.template_file.master_ips.*.rendered)}"

    master_node_internal_ip_list="${jsonencode(openstack_compute_instance_v2.dcos_master.*.access_ip_v4)}"
  }
}

output "ansible_inventory_info" {
  value="${data.template_file.ansible_inventory.rendered}"
}