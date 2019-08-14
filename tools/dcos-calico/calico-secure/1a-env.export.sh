# This will be customer-specific, so it's at the top
# This export file is used to generate env files for all systemd units

# Default config
CALICO_NAME=( 'calico' )
CALICO_CIDR=( '192.168.0.0/16' )

# Example config with multiple networks
# export CALICO_NAME=( 'calico-mercury' 'calico-venus' )
# export CALICO_CIDR=( '10.1.0.0/16' '10.2.0.0/16')

########

# 2379 and 2380 are within the DC/OS service port range, and are used by the etcd included with Calico.
export ETCD_LISTEN_PORT=62379
export ETCD_TRANSPORT_PORT=62380

## Env variables
export MASTER_LIST_NOPORT=$(curl -sS master.mesos:8181/exhibitor/v1/cluster/status | python -c 'import sys,json;j=json.loads(sys.stdin.read());print(",".join([y["hostname"]+"=https://"+y["hostname"]+":ETCD_TRANSPORT_PORT" for y in j]))')
export MASTER_LIST=$(echo $MASTER_LIST_NOPORT | sed "s|ETCD_TRANSPORT_PORT|${ETCD_TRANSPORT_PORT}|g")
export MASTER_LIST_OPEN=$(echo $MASTER_LIST | sed "s|https|http|g")

export ETCD_ROOT_DIR=/opt/etcd
export ETCD_DATA_DIR=/var/etcd/data
export ETCD_TLS_CERT=etcd.crt
export ETCD_TLS_KEY=etcd.key
export ETCD_CA_CERT=dcos-ca.crt
export LOCAL_HOSTNAME=$(/opt/mesosphere/bin/detect_ip)
export INITIAL_CLUSTER=${MASTER_LIST}
export INITIAL_CLUSTER_OPEN=${MASTER_LIST_OPEN}

export CALICO_CNI_PLUGIN_DIR=/opt/calico/bin
export CALICO_CNI_CONF_DIR=/etc/calico/cni

export CALICO_NODE_IMAGE=quay.io/calico/node:v2.6.10

export ETCD_CERTS_DIR=/etc/etcd/certs
export DOCKER_CLUSTER_CERTS_DIR=/etc/docker/cluster/certs
export CALICO_NODE_CERTS_DIR=/etc/calico/certs/node
export CALICO_CALICOCTL_CERTS_DIR=/etc/calico/certs/calicoctl
export CALICO_CNI_CERTS_DIR=/etc/calico/certs/cni