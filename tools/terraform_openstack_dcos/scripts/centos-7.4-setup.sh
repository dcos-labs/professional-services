sudo setenforce 0 && \
sudo sed -i --follow-symlinks 's/^SELINUX=.*/SELINUX=disabled/g' /etc/sysconfig/selinux
sudo tee /etc/yum.repos.d/docker.repo <<-'EOF'
[dockerrepo]
name=Docker Repository
baseurl=https://yum.dockerproject.org/repo/main/centos/7
enabled=1
gpgcheck=1
gpgkey=https://yum.dockerproject.org/gpg
EOF
# sudo yum -y update --exclude="docker-engine*"
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/systemd/system/docker.service.d/override.conf <<- EOF
[Service]
ExecStart=
ExecStart=/usr/bin/docker daemon --storage-driver=overlay
EOF
sudo yum install -y docker-engine-1.13.1
sudo systemctl start docker
sudo systemctl enable docker
sudo yum install -y bind-utils
sudo yum install -y wget
sudo yum install -y git
sudo yum install -y unzip
sudo yum install -y curl
sudo yum install -y xz
sudo yum install -y ipset
sudo yum install -y ntp
sudo systemctl enable ntpd
sudo systemctl start ntpd
sudo getent group nogroup || sudo groupadd nogroup
sudo getent group docker || sudo groupadd docker
sudo touch /opt/dcos-prereqs.installed



## parts from https://raw.githubusercontent.com/dcos/dcos/1.10/cloud_images/centos7/install_prereqs.sh - needed and/or better for Openstack environment
echo ">>> Adjusting SSH Daemon Configuration"

sed -i '/^\s*UseDNS /d' /etc/ssh/sshd_config
echo -e "\nUseDNS no" >> /etc/ssh/sshd_config


echo ">>> Update /etc/hosts on boot"
update_hosts_script=/usr/local/sbin/dcos-update-etc-hosts
update_hosts_unit=/etc/systemd/system/dcos-update-etc-hosts.service

mkdir -p "$(dirname $update_hosts_script)"

cat << 'EOF' > "$update_hosts_script"
#!/bin/bash
export PATH=/opt/mesosphere/bin:/sbin:/bin:/usr/sbin:/usr/bin
curl="curl -s -f -m 30 --retry 3"
fqdn=$($curl http://169.254.169.254/latest/meta-data/local-hostname)
ip=$($curl http://169.254.169.254/latest/meta-data/local-ipv4)
echo "Adding $fqdn if $ip is not in /etc/hosts"
grep ^$ip /etc/hosts > /dev/null || echo -e "$ip\t$fqdn ${fqdn%%.*}" >> /etc/hosts
EOF

chmod +x "$update_hosts_script"

cat << EOF > "$update_hosts_unit"
[Unit]
Description=Update /etc/hosts with local FQDN if necessary
After=network.target

[Service]
Restart=no
Type=oneshot
ExecStart=$update_hosts_script

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable $(basename "$update_hosts_unit")
systemctl start dcos-update-etc-hosts.service


# Make sure we wait until all the data is written to disk, otherwise
# Packer might quite too early before the large files are deleted
sync
