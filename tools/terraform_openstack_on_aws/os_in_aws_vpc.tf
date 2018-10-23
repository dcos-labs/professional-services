# needed info
# ami
# instance type
# ssh keypair
# EBS volume info (size, IOPS, ...) --> depends on

# Specify the provider and access details
provider "aws" {
  profile = "${var.aws_profile}"
  region = "${var.aws_region}"
}

locals {
  # cannot leave this empty as the file() interpolation will fail later on for the private_key local variable
  # https://github.com/hashicorp/terraform/issues/15605
  private_key = "${file(var.ssh_private_key_filename)}"
  agent = "${var.ssh_private_key_filename == "/dev/null" ? true : false}"
}

# Runs a local script to return the current user in bash
data "external" "whoami" {
  program = ["./whoami.sh"]
}

# Create a VPC to launch our instances into
resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = "true"

tags {
  owner = "${coalesce(var.owner, data.external.whoami.result["owner"])}"
  Name = "Openstack on AWS AIO Instance VPC / Terraform"
}
}

# Addressable Cluster UUID
data "template_file" "cluster_uuid" {
 template = "tf$${uuid}"

 vars {
    uuid = "${substr(md5(aws_vpc.default.id),0,4)}"
  }
}

# Allow overrides of the owner variable or default to whoami.sh
data "template_file" "cluster-name" {
 template = "$${username}-tf$${uuid}"

  vars {
    uuid = "${substr(md5(aws_vpc.default.id),0,4)}"
    username = "${format("%.10s", coalesce(var.owner, data.external.whoami.result["owner"]))}"
  }
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.default.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.default.id}"
}

# Create a subnet to launch public nodes into
resource "aws_subnet" "public" {
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "10.0.0.0/22"
  map_public_ip_on_launch = true
}

# A security group for SSH only access
resource "aws_security_group" "ssh" {
  name        = "ssh-security-group / Openstack on AWS"
  description = "SSH only access for terraform and administrators and sshuttle for Openstack"
  vpc_id      = "${aws_vpc.default.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.admin_cidr}"]
  }
}

# A security group for any machine to download artifacts from the web
# without this, an agent cannot get internet access to pull containers
# This does not expose any ports locally, just external access.
resource "aws_security_group" "internet-outbound" {
  name        = "internet-outbound-only-access / Openstack on AWS"
  description = "Security group to control outbound internet access only."
  vpc_id      = "${aws_vpc.default.id}"

 # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Deploy the bootstrap instance
resource "aws_instance" "openstack_on_aws" {
  # The connection block tells our provisioner how to
  # communicate with the resource (instance)
  connection {
    # The default username for our AMI
    user = "ubuntu"
    private_key = "${local.private_key}"
    agent = "${local.agent}"

    # set a higher timeout than the initial 5minutes (e.g. because i3.metal takes a lot longer to come up)
    timeout = "15m"

    # The connection will use the local SSH agent for authentication.
  }

  # might be a variable in the future
  private_ip = "10.0.0.5"

  root_block_device {
    volume_size = "${var.ebs_volume_size_in_gb}"
    # hopefully a lot more performance than the standard (old HDD)
    # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EBSVolumeTypes.html
    volume_type = "gp2"
  }

  ebs_optimized = "${var.ebs_optimized_iops}"

  instance_type = "${var.aws_instance_type}"

  tags {
   owner = "${coalesce(var.owner, data.external.whoami.result["owner"])}"
   Name = "Openstack on AWS AIO instance"
  }

  # use the specified golden image
  ami = "${var.aws_ami}"

  # The name of our SSH keypair we created above.
  key_name = "${var.ssh_key_name}"

  # Our Security group to allow http, SSH, and outbound internet access only for pulling containers from the web
  vpc_security_group_ids = ["${aws_security_group.ssh.id}", "${aws_security_group.internet-outbound.id}"]


  # We're going to launch into the same subnet as our ELB. In a production
  # environment it's more common to have a separate private subnet for
  # backend instances.
  subnet_id = "${aws_subnet.public.id}"

  # script that makes the
  provisioner "file" {
    source = "../openstack_setup_scripts/adapt_config_to_instance.sh"
    destination = "/home/ubuntu/adapt_config_to_instance.sh"
  }

  # script that provisions the Openstack environment (base images, dcos flavors, tenant/users, quota, ...)
  provisioner "file" {
    source = "../openstack_setup_scripts/prepare_openstack_env.sh"
    destination = "/home/ubuntu/prepare_openstack_env.sh"
  }


 # We run a remote provisioner on the instance after creating it.
  # In this case, we just install nginx and start it. By default,
  # this should be on port 80
  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /home/ubuntu/adapt_config_to_instance.sh",
      "sudo bash -x /home/ubuntu/adapt_config_to_instance.sh",
    ]
  }

  lifecycle {
    ignore_changes = ["tags.Name"]
  }
}

# TODO: poll until Openstack is really up (e.g. remote-exec curl dashboard URL and check for login prompt)


output "Public IP" {
  value = "${aws_instance.openstack_on_aws.public_ip}"
}
