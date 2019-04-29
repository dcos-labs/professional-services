source env.export
# Unused, but specified for consistency

# This should only be run on one master
sudo calicoctl get ipps -o json | sudo tee /etc/calico/ippool-backup.json
sudo calicoctl delete ipps 192.168.0.0/16
sudo calicoctl apply -f /etc/calico/ippool.json

sudo calicoctl get ipps -o json

### Set up Docker network
docker network create --driver calico --ipam-driver calico-ipam calico
