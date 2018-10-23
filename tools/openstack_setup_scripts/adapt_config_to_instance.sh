#!/bin/bash
# that script is supposed to adapt the golden image to the instance (type) it is running on (e.g. i3.metal)

# maybe do that manually for now and make an i3.metal snapshot? (short term) - with small enough EBS disk - e.g. initially 100GB
# adapt the network config (make sure the primary NIC is correctly configured - different in AWS VMs and BareMetal)
/sbin/iptables -t nat -D POSTROUTING -o ens5 -j MASQUERADE
/sbin/iptables -t nat -A POSTROUTING -o $(cat /etc/network/interfaces.d/50-cloud-init.cfg | grep 'inet dhcp' | awk '{print $2}') -j MASQUERADE
# if that works, it should be part of every golden image, since it works for normal AWS VMs as well as i3.metal - more generic

# make sure that apt-get does not go through a local proxy (was only really useful for the initial Openstack install)
sudo mv /etc/apt/apt.conf.d/00apt-cacher-proxy /home/ubuntu/
# install crudini to make the work on the nova.conf easier and more robust
sudo apt-get update && sudo apt-get install -y crudini

# adapt the Openstack Nova hardware virtualization settings (if wanted KVM hardware acceleration uisng i3.metal)
# virt_type=kvm, cpu_mode=host-passthrough

# backup existing nova.conf first (with timestamp)
sudo cp /etc/nova/nova.conf /etc/nova/nova.conf.$(date +%s)

# make sure the CPU overcommit is high, so it does not bother us (needs to be factored in for performance anyway, though)
sudo crudini --set --existing /etc/nova/nova.conf DEFAULT cpu_allocation_ratio 16.0
# change the following, so that we can launch more than 10 instances per host (quickly)
sudo crudini --set --existing /etc/nova/nova.conf filter_scheduler max_io_ops_per_host 20
sudo crudini --set --existing /etc/nova/nova.conf filter_scheduler host_subset_size 20
sudo lxc-attach -n $(sudo lxc-ls -1 | grep nova_scheduler) -- sudo service nova-scheduler restart

#sudo crudini --set --existing /etc/nova/nova.conf DEFAULT metadata_workers 5
#sudo lxc-attach -n $(sudo lxc-ls -1 | grep aio1_nova_api_metadata_container) -- sudo service nova-api-metadata restart

#sudo crudini --set --existing /etc/nova/nova.conf DEFAULT osapi_compute_workers 5
#sudo lxc-attach -n $(sudo lxc-ls -1 | grep aio1_nova_api_os_compute_container) -- sudo service nova-api-os-compute restart


if [ -e "/dev/kvm" ]; then
    sudo crudini --set --existing /etc/nova/nova.conf libvirt virt_type kvm
    sudo crudini --set --existing /etc/nova/nova.conf libvirt cpu_mode host-passthrough
else
    sudo crudini --set --existing /etc/nova/nova.conf libvirt virt_type qemu
    sudo crudini --set --existing /etc/nova/nova.conf libvirt cpu_mode none
fi

sudo service nova-compute restart

while [ $(curl -I -k https://10.0.0.5:443 2>/dev/null | head -n 1 | cut -d$' ' -f2) == '503' ]
do
    echo "Waiting for the Horizon dashboard to come up with NOT HTTP 503"
    sleep 5
done