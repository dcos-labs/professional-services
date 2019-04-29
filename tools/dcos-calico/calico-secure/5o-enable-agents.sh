source env.export


####### etcd
# Install, enable, and start etcd systemd unit (can be run independently on all agents)
sudo cp /etc/etcd/dcos-etcd-proxy-open.service /etc/systemd/system/dcos-etcd-proxy.service

sudo systemctl daemon-reload
sudo systemctl enable dcos-etcd-proxy.service
sudo systemctl restart dcos-etcd-proxy.service

# Validate it's running (etcd must be running on all masters prior to this working)
sudo ETCDCTL_API=2 /opt/etcd/etcdctl \
  --endpoints http://localhost:${ETCD_LISTEN_PORT} \
  cluster-health





####### Docker cluster store
# Get docker to pick up the new config
# !!! If this fails, you may have to remove the 'overlay' line from /etc/docker/daemon.json - it doesn't like redundant configurations
if [[ $(systemctl cat docker | grep 'storage-driver=overlay' | wc -l) -eq 1 ]]; then
  sudo sed -i "/storage-driver/d" /etc/docker/daemon.json
fi
sudo systemctl restart docker

# Validate
sudo docker info | grep -i cluster


####### Calico node
sudo cp /etc/calico/dcos-calico-node-open.service /etc/systemd/system/dcos-calico-node.service
sudo cp /etc/calico/dcos-calico-node-open.timer /etc/systemd/system/dcos-calico-node.timer

sudo systemctl daemon-reload
sudo systemctl enable dcos-calico-node.service
sudo systemctl restart dcos-calico-node.service

sudo systemctl enable dcos-calico-node.timer
sudo systemctl restart dcos-calico-node.timer

# Check status
sleep 5
sudo calicoctl node status


####### Set up CNI
## Plugin dir
# Copy setting from /opt/mesosphere/etc/mesos-slave-common to /var/lib/dcos/mesos-slave-common
# Append custom CALICO_CNI_PLUGIN_DIR
# Running this multiple times will create duplicate and ugly but not harmful settings
grep MESOS_NETWORK_CNI_PLUGINS_DIR /opt/mesosphere/etc/mesos-slave-common | sudo tee -a /var/lib/dcos/mesos-slave-common
sudo sed -i '/MESOS_NETWORK_CNI_PLUGINS_DIR/s|$|:CALICO_CNI_PLUGIN_DIR|g' /var/lib/dcos/mesos-slave-common
sudo sed -i "s|CALICO_CNI_PLUGIN_DIR|${CALICO_CNI_PLUGIN_DIR}|g" /var/lib/dcos/mesos-slave-common

## Plugin conf
sudo mkdir -p /etc/systemd/system/dcos-mesos-slave.service.d
# We can do both dcos-mesos-slave and dcos-mesos-slave-common on all nodes, safely; only the relevant one will be used by the corresponding systemd unit
# We use a systemd override to copy the conf from custom location into default MESOS_NETWORK_CNI_CONFIG_DIR
sudo tee /etc/systemd/system/dcos-mesos-slave.service.d/dcos-calico-conf-override.conf <<-'EOF'
[Service]
ExecStartPre=/bin/cp CALICO_CNI_CONF_DIR/CALICO_CNI_CONF_FILE /opt/mesosphere/etc/dcos/network/cni/
EOF

sudo sed -i "s|CALICO_CNI_CONF_DIR|${CALICO_CNI_CONF_DIR}|g" /etc/systemd/system/dcos-mesos-slave.service.d/dcos-calico-conf-override.conf
sudo sed -i "s|CALICO_CNI_CONF_FILE|${CALICO_CNI_CONF_FILE}|g" /etc/systemd/system/dcos-mesos-slave.service.d/dcos-calico-conf-override.conf

sudo mkdir -p /etc/systemd/system/dcos-mesos-slave-public.service.d
# /etc/systemd/system/dcos-mesos-slave.service.d/override.conf
sudo tee /etc/systemd/system/dcos-mesos-slave-public.service.d/dcos-calico-conf-override.conf <<-'EOF'
[Service]
ExecStartPre=/bin/cp CALICO_CNI_CONF_DIR/CALICO_CNI_CONF_FILE /opt/mesosphere/etc/dcos/network/cni/
EOF

sudo sed -i "s|CALICO_CNI_CONF_DIR|${CALICO_CNI_CONF_DIR}|g" /etc/systemd/system/dcos-mesos-slave-public.service.d/dcos-calico-conf-override.conf
sudo sed -i "s|CALICO_CNI_CONF_FILE|${CALICO_CNI_CONF_FILE}|g" /etc/systemd/system/dcos-mesos-slave-public.service.d/dcos-calico-conf-override.conf

## Restart
sudo systemctl daemon-reload
sudo systemctl restart dcos-mesos-slave*
