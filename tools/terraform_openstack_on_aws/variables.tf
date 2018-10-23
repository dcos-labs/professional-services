variable "aws_profile" {
  description = "AWS profile to use"
  default     = ""
}

variable "aws_region" {
  default = "us-west-2"
}

variable "aws_instance_type" {
  default = "m4.xlarge"
}

variable "aws_ami" {
  default = "ami-040a0c972599d751d"
}

variable "ebs_volume_size_in_gb" {
  default = 100
}

variable "ebs_optimized_iops" {
  default = true
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

variable "admin_cidr" {
  default = "0.0.0.0/0"
}

variable "owner" {
  default = ""
}


