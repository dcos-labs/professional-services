#!/bin/bash
# first source the Admin openrc file
source /root/openrc

# create normal tenant and user (not the admin) + sufficient quota - so it can be used by SEs, ...
#openstack project create --description 'Mesosphere-default' Mesosphere-default --domain default
#openstack user create --project Mesosphere-default --password "mesosphere" mesosphere

# https://docs.openstack.org/python-openstackclient/pike/cli/command-objects/quota.html
openstack quota set \
    --cores 200 \
    --fixed-ips 100 \
    --floating-ips 100 \
    --injected-file-size 100000 \
    --injected-files 100 \
    --instances 100 \
    --key-pairs 100 \
    --properties 100 \
    --ram 512000 \
    --server-groups 100 \
    --server-group-members 100 \
    --backups 100 \
    --backup-gigabytes 100 \
    --gigabytes 1000 \
    --per-volume-gigabytes 100 \
    --snapshots 100 \
    --volumes 100 \
    --floating-ips 100 \
    --secgroup-rules 1000 \
    --secgroups 100 \
    --networks 100 \
    --subnets 100 \
    --ports 500 \
    --routers 100 \
    admin


# setup SSH keypairs (take it from the authorized_keys
# https://docs.openstack.org/python-openstackclient/pike/cli/command-objects/keypair.html
openstack keypair create --public-key /home/ubuntu/.ssh/authorized_keys dcos-default

# create instance types (master, private_agent, public_agent)
#openstack flavor create --id 301 --vcpus 4 --ram 32768 --disk 120 dcos.master
#openstack flavor create --id 302 --vcpus 2 --ram 16384 --disk 60 dcos.agent
# slightly more beefy flavors (e.g. for i3.metal)
openstack flavor create --id 301 --vcpus 8 --ram 65536 --disk 120 dcos.master
openstack flavor create --id 302 --vcpus 4 --ram 32768 --disk 60 dcos.agent
openstack flavor create --id 303 --vcpus 2 --ram 4096 --disk 20 dcos.bootstrap



# download and upload to Glance (CoreOS + CentOS images)
# https://docs.openstack.org/glance/pike/admin/manage-images.html
wget https://stable.release.core-os.net/amd64-usr/1235.12.0/coreos_production_openstack_image.img.bz2
bzip2 -d coreos_production_openstack_image.img.bz2
openstack image create --public --disk-format qcow2 --container-format bare --file coreos_production_openstack_image.img coreos_1235.12.0

# the following image is a CentOS 7.4 image
wget https://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud-1801-01.qcow2
openstack image create --public --disk-format qcow2 --container-format bare --file CentOS-7-x86_64-GenericCloud-1801-01.qcow2 CentOS7-1801
