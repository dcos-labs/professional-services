variable "image" {
  #default = "coreos_1235.12.0"
  default = "CentOS7-1801"
  #default = "cirros"
}

variable "ssh_user_name" {
  default = "centos"
}

variable "ip_detect_file" {
  default = "scripts/ip-detect.openstack.sh"
}

variable "os_setup_script_file" {
  default = "scripts/centos-7.4-setup.sh"
}

variable "num_of_masters" {}
variable "num_of_private_agents" {}
variable "num_of_public_agents" {}

variable "bootstrap_flavor" {
  default = "dcos.bootstrap"
}

variable "master_flavor" {
  default = "dcos.master"

}

variable "private_agent_flavor" {
  default = "dcos.agent"
}

variable "public_agent_flavor" {
  default = "dcos.agent"

}

variable "ssh_key_name" {
  default = "dcos-default"
}

variable "ssh_private_key_filename" {
 # cannot leave this empty as the file() interpolation will fail later on for the private_key local variable
 # https://github.com/hashicorp/terraform/issues/15605
 default = "/dev/null"
 description = "Path to file containing your ssh private key"
}

variable "external_gateway" {}

variable "pool" {
  default = "public"
}
