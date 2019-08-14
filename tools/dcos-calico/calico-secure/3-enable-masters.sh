source 1a-env.export.sh
# Unused, but specified for consistency

####### etcd
# Install, enable, and start etcd systemd unit (will hang until it's run on all masters)
sudo cp /etc/etcd/dcos-etcd.service /etc/systemd/system/dcos-etcd.service

sudo systemctl daemon-reload
sudo systemctl enable dcos-etcd.service
sudo systemctl restart dcos-etcd.service

# Validate it's running (etcd must be running on all masters prior to this working)
sudo ETCDCTL_API=2 /opt/etcd/etcdctl \
  --endpoints https://localhost:${ETCD_LISTEN_PORT} \
  --key-file /etc/etcd/certs/etcd.key \
  --cert-file /etc/etcd/certs/etcd.crt \
  --ca-file /etc/etcd/certs/dcos-ca.crt \
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


####### Calico node (used so that masters can reach container IPs)
sudo cp /etc/calico/dcos-calico-node.service /etc/systemd/system/dcos-calico-node.service
sudo cp /etc/calico/dcos-calico-node.timer /etc/systemd/system/dcos-calico-node.timer

sudo systemctl daemon-reload
sudo systemctl enable dcos-calico-node.service
sudo systemctl restart dcos-calico-node.service

sudo systemctl enable dcos-calico-node.timer
sudo systemctl restart dcos-calico-node.timer

# Check status
until sudo calicoctl node status &> /dev/null
do
    echo "Waiting for calico node status..."
    sleep 1
done

