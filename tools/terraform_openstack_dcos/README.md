# Variables

|Variable Name              |Description                                                                        |
|---------------------------|-----------------------------------------------------------------------------------|
|image                      | Openstack virtual machine image used for the launched VMs                         |
|ssh_user_name              | Username of the VM user the SSH keypair gets injected to.                         |
|ip_detect_file             | Path to DC/OS IP detect script.                                                   |
|os_setup_script_file       | Path to Operating System setup script.                                            |
|num_of_masters             | Count of masters in the DC/OS deployment.                                         |
|num_of_private_agents      | Count of private agents in the DC/OS deployment.                                  |
|num_of_public_agents       | Count of public agents in the DC/OS deployment.                                   |
|bootstrap_flavor           | Instance type/Flavor to be used for the Bootstrap VM.                             |
|master_flavor              | Instance type/Flavor to be used for the Master VMS .                              |
|private_agent_flavor       | Instance type/Flavor to be used for the Private Agent VMs.                        |
|public_agent_flavor        | Instance type/Flavor to be used for the Public Agrent VM.                         |
|ssh_key_name               | Openstack SSH keypair that should be injected into the VMs.                       |
|ssh_private_key_filename   | (Local) path to private SSH key (corresponding to the injected public SSH key.    |
|external_gateway           | see details below                                                                 |
|pool                       | see details below                                                                 |

You need to select an Openstack floating IP pool which you will use to expose the VMs in the cluster - e.g. to your system that runs
the Ansible scripts against it via SSH. The following example shows how to get the external_gateway ID for the assumed floating IP
pool named 'public':

https://github.com/terraform-providers/terraform-provider-openstack/tree/master/examples/app-with-networking


# Installation process

Source the Openstack RC-File so Terraform can authenticate and act against the Openstack API endpoints.

``` bash
source <PATH-TO-RC-File>
```

Apply the terraform automation scripts with a var-file adapted to your needs and adapt/lower the Terraform (API call) concurrency if needed.
For the Openstack AIO test environment a parallelism of 3 is a good setting.

``` bash
terraform apply -var-file <TERRAFORM-VAR-FILE> -parallelism=3
``` 

Explicitly output the hosts.yaml that can be consumed by Ansible automation scripts.

``` bash
mkdir -p rendered_files
terraform output ansible_inventory_info > rendered_files/openstack_inventory.yaml
```

Make sure that the inventory file generated by Terraform is available to Ansible as hosts.yaml.

``` bash
cd <PATH-TO-DCOS-ANSIBLE-DCOS>
cp <PATH-TO-OPENSTACK-TERRAFORM>/rendered_files/openstack_inventory.yaml hosts.yaml
```

Run a quick check, if ansible can reach all Openstack VMs listed in the hosts.yaml:

``` bash
ansible all -a hostname
```

Run the configured Ansible playbooks.
Refer to https://github.com/dcos-labs/ansible-dcos/blob/master/docs/INSTALL_ONPREM.md for further details on configuration.

``` bash
ansible-playbook plays/install.yml
```
