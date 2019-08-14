source 1a-env.export.sh


sudo mkdir -p ${CALICO_CNI_PLUGIN_DIR}
sudo mkdir -p ${CALICO_CNI_CONF_DIR}


#### Docker daemon config; Specifies cluster-store and storage driver.  If storage-driver is configured in docker systemd unit, it must be removed from here.
sudo tee /etc/docker/daemon.json <<-'EOF'
{
    "storage-driver": "overlay",
    "cluster-store": "etcd://127.0.0.1:ETCD_LISTEN_PORT",
    "cluster-store-opts": {
        "kv.cacertfile": "DOCKER_CLUSTER_CERTS_DIR/dcos-ca.crt",
        "kv.certfile": "DOCKER_CLUSTER_CERTS_DIR/docker-etcd.crt",
        "kv.keyfile": "DOCKER_CLUSTER_CERTS_DIR/docker-etcd.key"
    }
}
EOF
sudo sed -i "s|DOCKER_CLUSTER_CERTS_DIR|${DOCKER_CLUSTER_CERTS_DIR}|g" /etc/docker/daemon.json
sudo sed -i "s|ETCD_LISTEN_PORT|${ETCD_LISTEN_PORT}|g" /etc/docker/daemon.json


#### Mesos CNI Config

# clean up
rm -Rf ${CALICO_CNI_CONF_DIR}/dcos.*.conf

total=${#CALICO_NAME[*]}

for (( i=0; i<=$(( $total -1 )); i++ ))
do 

CALICO_CNI_CONF_FILE="dcos.${CALICO_NAME[$i]}.conf"

sudo tee ${CALICO_CNI_CONF_DIR}/${CALICO_CNI_CONF_FILE} <<-'EOF'
{
  "name": "CALICO_NAME",
  "cniVersion": "0.1.0",
  "type": "calico",
  "ipam": {
      "type": "calico-ipam",
      "ipv4_pools": ["CALICO_CIDR"]
  },
  "etcd_endpoints": "https://127.0.0.1:ETCD_LISTEN_PORT",
  "etcd_ca_cert_file": "CALICO_CNI_CERTS_DIR/dcos-ca.crt",
  "etcd_key_file": "CALICO_CNI_CERTS_DIR/calico.key",
  "etcd_cert_file": "CALICO_CNI_CERTS_DIR/calico.crt"
}
EOF
sudo sed -i "s|CALICO_CIDR|${CALICO_CIDR[$i]}|g" ${CALICO_CNI_CONF_DIR}/${CALICO_CNI_CONF_FILE}
sudo sed -i "s|CALICO_NAME|${CALICO_NAME[$i]}|g" ${CALICO_CNI_CONF_DIR}/${CALICO_CNI_CONF_FILE}
sudo sed -i "s|CALICO_CNI_CERTS_DIR|${CALICO_CNI_CERTS_DIR}|g" ${CALICO_CNI_CONF_DIR}/${CALICO_CNI_CONF_FILE}
sudo sed -i "s|ETCD_LISTEN_PORT|${ETCD_LISTEN_PORT}|g" ${CALICO_CNI_CONF_DIR}/${CALICO_CNI_CONF_FILE}

done


#### calicoctl config (config for command line tool)
sudo tee /etc/calico/calicoctl.cfg <<-'EOF'
apiVersion: v1
kind: calicoApiConfig
metadata:
spec:
  etcdEndpoints: https://127.0.0.1:ETCD_LISTEN_PORT
  etcdKeyFile: CALICO_CALICOCTL_CERTS_DIR/calico.key
  etcdCertFile: CALICO_CALICOCTL_CERTS_DIR/calico.crt
  etcdCACertFile: CALICO_CALICOCTL_CERTS_DIR/dcos-ca.crt 
EOF
sudo sed -i "s|CALICO_CALICOCTL_CERTS_DIR|${CALICO_CALICOCTL_CERTS_DIR}|g" /etc/calico/calicoctl.cfg
sudo sed -i "s|ETCD_LISTEN_PORT|${ETCD_LISTEN_PORT}|g" /etc/calico/calicoctl.cfg


#### Calico Pool Config (realistically, this is only used once on one node, but it's good to have for reference purposes)

total=${#CALICO_NAME[*]}

for (( i=0; i<=$(( $total -1 )); i++ ))
do 

sudo tee "/etc/calico/ippool-${CALICO_NAME[$i]}.json" <<-'EOF'
  {
    "kind": "ipPool",
    "apiVersion": "v1",
    "metadata": {
      "cidr": "CALICO_CIDR"
    },
    "spec": {
      "nat-outgoing": true,
      "ipip": {
        "enabled": true,
        "mode": "cross-subnet"
      }
    }
  }
EOF

sudo sed -i "s|CALICO_CIDR|${CALICO_CIDR[$i]}|g" /etc/calico/ippool-${CALICO_NAME[$i]}.json

done
