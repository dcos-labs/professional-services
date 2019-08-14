source 1a-env.export.sh


## Scriptlet used to generate certs using DC/OS CA
tee bootstrap-certs.py <<-'EOF'
#!/opt/mesosphere/bin/python

import sys
sys.path.append('/opt/mesosphere/lib/python3.6/site-packages')

from dcos_internal_utils import bootstrap

if len(sys.argv) == 1:
    print("Usage: ./bootstrap-certs.py <CN> <PATH> | ./bootstrap-certs.py etcd /var/lib/dcos/etcd/certs")
    sys.exit(1)

b = bootstrap.Bootstrapper(bootstrap.parse_args())
b.read_agent_secrets()

cn = sys.argv[1]
location = sys.argv[2]

keyfile = location + '/' + cn + '.key'
crtfile = location + '/' + cn + '.crt'

b.ensure_key_certificate(cn, keyfile, crtfile, service_account='dcos_bootstrap_agent')
EOF
chmod +x bootstrap-certs.py

## Etcd certs
sudo mkdir -p ${ETCD_CERTS_DIR}

sudo ./bootstrap-certs.py etcd ${ETCD_CERTS_DIR}
sudo curl -kL https://master.mesos/ca/dcos-ca.crt -o ${ETCD_CERTS_DIR}/dcos-ca.crt

## Docker certs
sudo mkdir -p ${DOCKER_CLUSTER_CERTS_DIR}

sudo ./bootstrap-certs.py docker-etcd ${DOCKER_CLUSTER_CERTS_DIR}
sudo curl -kL http://master.mesos/ca/dcos-ca.crt -o ${DOCKER_CLUSTER_CERTS_DIR}/dcos-ca.crt

## Calico Node certs
sudo mkdir -p ${CALICO_NODE_CERTS_DIR}

sudo ./bootstrap-certs.py calico ${CALICO_NODE_CERTS_DIR}
sudo curl -kL http://master.mesos/ca/dcos-ca.crt -o ${CALICO_NODE_CERTS_DIR}/dcos-ca.crt

## Calicoctl certs
sudo mkdir -p ${CALICO_CALICOCTL_CERTS_DIR}

sudo ./bootstrap-certs.py calico ${CALICO_CALICOCTL_CERTS_DIR}
sudo curl -kL http://master.mesos/ca/dcos-ca.crt -o ${CALICO_CALICOCTL_CERTS_DIR}/dcos-ca.crt

## CNI Certs
sudo mkdir -p ${CALICO_CNI_CERTS_DIR}

sudo ./bootstrap-certs.py calico ${CALICO_CNI_CERTS_DIR}
sudo curl -kL https://master.mesos/ca/dcos-ca.crt -o ${CALICO_CNI_CERTS_DIR}/dcos-ca.crt

## Other misc. directories
sudo mkdir -p ${ETCD_DATA_DIR}
