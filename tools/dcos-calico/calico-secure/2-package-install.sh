source env.export


sudo mkdir -p ${ETCD_ROOT_DIR}
sudo mkdir -p ${ETCD_DATA_DIR}


## Download and extract etcd package
curl -LO https://github.com/coreos/etcd/releases/download/v3.3.5/etcd-v3.3.5-linux-amd64.tar.gz
sudo tar -xzvf etcd-v3.3.5-linux-amd64.tar.gz -C ${ETCD_ROOT_DIR} --strip-components=1


## Download and install calico and calico-ipam CNI plugin binaries
sudo curl -L https://github.com/projectcalico/cni-plugin/releases/download/v1.11.6/calico -o ${CALICO_CNI_PLUGIN_DIR}/calico
sudo curl -L https://github.com/projectcalico/cni-plugin/releases/download/v1.11.6/calico-ipam -o ${CALICO_CNI_PLUGIN_DIR}/calico-ipam
sudo chmod +x ${CALICO_CNI_PLUGIN_DIR}/calico
sudo chmod +x ${CALICO_CNI_PLUGIN_DIR}/calico-ipam


## Download calicoctl
sudo curl -L https://github.com/projectcalico/calicoctl/releases/download/v1.6.4/calicoctl -o /usr/bin/calicoctl
sudo chmod +x /usr/bin/calicoctl


## Download Docker image for Calico node
sudo docker pull ${CALICO_NODE_IMAGE}
