---
# Example for an ansible inventory file
all:
  children:
    bootstraps:
      hosts:
        # Public IP Address of the Bootstrap Node
        ${bootstrap_node_public_ip}:
    masters:
      hosts:
        # Public IP Addresses for the Master Nodes
${master_node_ip_block}
    agents:
      hosts:
        # Public IP Addresses for the Agent Nodes
${private_agent_node_ip_block}
    agent_publics:
      hosts:
        # Public IP Addresses for the Public Agent Nodes
${public_agent_node_ip_block}
  vars:
    # IaaS target for DC/OS deployment
    # options: aws, gcp, azure or onprem
    dcos_iaas_target: 'onprem'

    # Choose the IP Detect Script
    # options: eth0, eth1, ... (or other device name for existing network interface)
    dcos_ip_detect_interface: 'eth0'

    # (internal/private) IP Address of the Bootstrap Node
    dcos_bootstrap_ip: '${bootstrap_node_internal_ip}'

    # (internal/private) IP Addresses for the Master Nodes
    dcos_master_list:
      ${master_node_internal_ip_list}

    # DNS Resolvers
    dcos_resolvers:
      - 8.8.4.4
      - 8.8.8.8

    # DNS Search Domain
    dcos_dns_search: 'None'