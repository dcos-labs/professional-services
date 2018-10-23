# Openstack on AWS
## Check AWS Instance Types for KVM acceleration
In order to experience appropriate performance of DC/OS on Openstack on AWS, the Openstack VMs should be able to utilize real hardware-acceleration. Without hardware acceleration QEMU emulation would need to be used. Quick tests showed that the performance of software emulation was about 10x slower than with hardware acceleration.

Being restricted to AWS as the resource provider, a couple of tests were made to identify EC2 instance types that offer hardware acceleration.

The following links describe how to find out if KVM hardware acceleration might be used:
https://help.ubuntu.com/community/KVM/Installation

The next link indicates that AWS’ instance type i3.metal might actually expose hardware acceleration capabilities to the running EC2 instance.
https://www.twosixlabs.com/running-thousands-of-kvm-guests-on-amazons-new-i3-metal-instances/
→ *Quote: “Amazon has recently released to general availability the i3.metal instance, which allows us to do some things which we could not do before in the Amazon cloud, such as running an unmodified hypervisor. ”*

The following quick test of 3 instance types showed that only i3.metal really seems to expose the needed CPU capabilities.

**M5.large**
``` bash
ubuntu@ip-172-31-35-172:~$ sudo kvm-ok
INFO: Your CPU does not support KVM extensions
KVM acceleration can NOT be used
```

**I3.large  (hvm-ssd)**
```bash
ubuntu@ip-172-31-7-140:~$ sudo kvm-ok
INFO: Your CPU does not support KVM extensions
KVM acceleration can NOT be used
```

**I3.metal (hvm-ssd)**
``` bash
ubuntu@ip-172-31-7-186:~$ ls /dev/kvm
/dev/kvm

ubuntu@ip-172-31-7-186:~$ sudo kvm-ok
INFO: /dev/kvm exists
KVM acceleration can be used

ubuntu@ip-172-31-7-186:~$ sudo lsblk
NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
loop0         7:0    0 87.9M  1 loop /snap/core/5328
loop1         7:1    0 12.7M  1 loop /snap/amazon-ssm-agent/495
nvme0n1     259:8    0    8G  0 disk
└─nvme0n1p1 259:9    0    8G  0 part /
nvme1n1     259:5    0  1.7T  0 disk
nvme2n1     259:4    0  1.7T  0 disk
nvme3n1     259:2    0  1.7T  0 disk
nvme4n1     259:3    0  1.7T  0 disk
nvme5n1     259:0    0  1.7T  0 disk
nvme6n1     259:6    0  1.7T  0 disk
nvme7n1     259:7    0  1.7T  0 disk
nvme8n1     259:1    0  1.7T  0 disk
```

## Tests with Openstack-Ansible as Install Method
From the myriads of Openstack install options currently available, Openstack-Ansible seems to be the best supported install method which is open-source, community-driven and not vendor-specific.

The main (entry) repository can be found here:  https://github.com/openstack/openstack-ansible
The docs are here: https://docs.openstack.org/openstack-ansible/latest/

The initial target installation release of Openstack was Newton. Newton is in Openstack terms quite an old release, it was released at the end of 2016. Openstack has a half-year release-cycle. More info on Openstack releases can be found here: https://releases.openstack.org/

As of October 2018, Openstack-Ansible itself only actively supports versions from Ocata onwards, with an EOL for Ocata coming soon as well.

Nevertheless it was tried to install Openstack-ansible Newton first. Unfortunately many essential code changes in Openstack-Ansible  have not been backported to the Newton release. Therefore, it is not possible to install Openstack Newton without very substantial changes and basically forking Openstack-ansible and providing projects.

The decision was made to proceed with the Openstack Pike release. While it is a newer release than Newton (one year newer), it is still actively supported and the user-facing APIs have stayed the same. The Openstack APIs, e.g. used by Terraform, should behave the same as they would with a Newton installation. The stability and performance might just be better.
Using “Golden Images”
The deployment of Openstack using the Ansible installer on a fresh Ubuntu 16.04 AWS EC2 instance takes about 1:30 hours - just the pure (error-free) runtime of the Ansible scripts. In reality errors might occur and additional configuration work would need to be done - so a lot more than 1:30 hours could be anticipated.

Therefore the decision to test snapshotted EBS AMIs (aka Golden Images) was made. In combination with the later use of the EC2 i3.metal instances the time between a Terraform launch of such a golden image (AMI) and a usable Openstack Pike installation (on AWS) was minimized to 10-15min.
Ansible to install DC/OS on top of Openstack
The actual installation of DC/OS itself will be done via Ansible using the scripts available in https://github.com/dcos-labs/ansible-dcos .

## Prerequisites to run Openstack on AWS
### Openstack AIO needs to run inside VPC

At the install time of Openstack with Ansible a couple of configurations are made based on the used private IP of the AWS instance at that time. In order to provide the convenient and quick user experience to launch Openstack off of a golden (snapshotted) image, one needs to make sure that the same private IP is always the same. In AWS it is only possible to determine the private IP when the instance is launched inside the VPC construct.

Terraform automation scripts to launch a new Openstack VM off of a golden image inside a VPC are provided for convenience. (--> TODO: let’s determine how to provide that part for consumption in the group - likely separately from automation on top of Openstack to provide instances for DC/OS installation)

All access to Openstack APIs and VMs tunneled through SSH
Generally Openstack is an IaaS solution and AWS does not support running arbitrary IaaS solutions as workloads on their platform. Limitations exist regarding packages flowing from Openstack instances via AWS network infrastructure, for example. In order to mitigate this problem, Openstack is treated as a normal workload (from the perspective of EC2). It is only installed as an All-In-one, running on a single (big) instance. To provide network access to the Openstack APIs and the running VMs, a solution on top of SSH is used.

The EC2 instance running Openstack AIO is only accessible via locked-down SSH (SSH keypair, adapted security group settings).

The actual VPN-like solution on top of SSH utilizes client-side SSH configuration and SSHuttle. It works on Linux-based systems and MacOS.

The repo for SSHuttle: https://github.com/sshuttle/sshuttle
The docs for SSHuttle: https://sshuttle.readthedocs.io/en/stable/

An example combination of SSH client config and SSHuttle would be:


example SSH config section (e.g. in **~/.ssh/config**)

``` bash
Host Openstack_on_AWS_10-0-0-5
    Hostname <Public IP of EC2 instance>
    ForwardAgent yes
    Port 22
    User ubuntu
    IdentityFile <path to SSH private key>
    #  SSH keep alive settings for more solid SSHuttle experience on idling connections
    ServerAliveInterval 120
    ServerAliveCountMax 2
```

example bash script to launch SSHuttle (on configured SSH connection)

``` bash
sshuttle -r Openstack_on_AWS_10-0-0-5 172.0.0.0/8 10.0.0.0/8
```

Basically sshuttle reroutes every connection that goes to the IP ranges 172.0.0.0/8 and 10.0.0.0/8 through the SSH connection Openstack_on_AWS_10-0-0-5 while it is active. For the Openstack AIO instance the ranges contain the Openstack API endpoints as well as the configured floating/public IPs via which the actual running Openstack instances can later be accessed.


### Provisioning of Openstack VMs to install DC/OS on them

The DC/OS Ansible install script needs hosts to install DC/OS onto. A set of Terraform automation scripts is provided to launch Openstack VMs which are then later installed by the DC/OS Ansible installer. The Terraform scripts output a hosts.yaml that will be used by Ansible to install DC/OS.

Also a basic script is provided that prepares Openstack. It configures necessary resource quotas, uploads a SSH keypair, provides Openstack flavors/instance types.


#### Terraform script variables


|Variable Name              |Description                                                                        |
|---------------------------|-----------------------------------------------------------------------------------|
|aws_profile                | AWS profile to use.                                                               |
|aws_region                 | AWS region to use.                                                                |
|aws_instance_type          | AWS instance type to launch Openstack All-In-One on.                              |
|aws_ami                    | "Golden Image" AMI to use for Openstack AIO launch.                               |
|ebs_volume_size_in_gb      | EBS root volume size in GB - e.g. important for DC/OS VM sizing                   |
|ebs_optimized_iops         | Utilize EBS optimized IOPS?                                                       |
|ssh_key_name"              | name of used AWS SSH keypair                                                      |
|ssh_private_key_filename   | (Local) path to private SSH key (corresponding to the injected public SSH key.    |
|admin_cidr                 | CIDR-notated IP range that should be allowed to access the VM via SSH.            |
|owner                      | String indicating the owner/launcher of the launched VM instance.                 |


#### Launching

Adapt the example Terraform var file and launch it via Terraform apply.

``` bash
terraform apply -var-file <TERRAFORM-VAR-FILE>
```

Wait for the process to finish and use the outputted public IP address of the launched VM to update your SSH config.

Now you can use SSH and SSHuttle to access to launched VM and the Openstack installation running on top of it.

#### Finding the Openstack RC file

Login to the launched VM via SSH and find the rc file under **/root/openrc**. You will need that file and the contained info to use
Openstack and its API.
