source env.export


sudo mkdir -p /etc/etcd
sudo mkdir -p /etc/calico


#### etcd systemd environment file
sudo rm -f /etc/etcd/etcd.env
echo "ETCD_ROOT_DIR=${ETCD_ROOT_DIR}" | sudo tee -a /etc/etcd/etcd.env
echo "ETCD_DATA_DIR=${ETCD_DATA_DIR}" | sudo tee -a /etc/etcd/etcd.env
echo "ETCD_CERTS_DIR=${ETCD_CERTS_DIR}" | sudo tee -a /etc/etcd/etcd.env
echo "ETCD_TLS_CERT=${ETCD_TLS_CERT}" | sudo tee -a /etc/etcd/etcd.env
echo "ETCD_TLS_KEY=${ETCD_TLS_KEY}" | sudo tee -a /etc/etcd/etcd.env
echo "ETCD_CA_CERT=${ETCD_CA_CERT}" | sudo tee -a /etc/etcd/etcd.env
echo "LOCAL_HOSTNAME=${LOCAL_HOSTNAME}" | sudo tee -a /etc/etcd/etcd.env
echo "INITIAL_CLUSTER=${INITIAL_CLUSTER}" | sudo tee -a /etc/etcd/etcd.env
echo "INITIAL_CLUSTER_OPEN=${INITIAL_CLUSTER_OPEN}" | sudo tee -a /etc/etcd/etcd.env
echo "ETCD_LISTEN_PORT=${ETCD_LISTEN_PORT}" | sudo tee -a /etc/etcd/etcd.env
echo "ETCD_TRANSPORT_PORT=${ETCD_TRANSPORT_PORT}" | sudo tee -a /etc/etcd/etcd.env

sed "s/^/export /g" /etc/etcd/etcd.env | sudo tee /etc/etcd/etcd.env.export


#### calico node systemd environment file
sudo tee /etc/calico/calico.env <<-'EOF'
ETCD_ENDPOINTS="https://localhost:ETCD_LISTEN_PORT"
ETCD_ENDPOINTS_OPEN="http://localhost:ETCD_LISTEN_PORT"
ETCD_CERT_DIR="ETCD_CERT_DIR_ENV"
ETCD_CONTAINER_CERT_DIR="/etc/certs"
ETCD_CA_CERT_FILE="dcos-ca.crt"
ETCD_CERT_FILE="calico.crt"
ETCD_KEY_FILE="calico.key"
CALICO_NODENAME=""
CALICO_NO_DEFAULT_POOLS=""
CALICO_IP="DETECT_IP_OUTPUT"
CALICO_IP6=""
CALICO_AS=""
CALICO_LIBNETWORK_ENABLED=true
CALICO_NETWORKING_BACKEND=bird
CALICO_DOCKER_IMAGE=CALICO_NODE_IMAGE
EOF

sudo sed -i "s|ETCD_CERT_DIR_ENV|${CALICO_NODE_CERTS_DIR}|g" /etc/calico/calico.env
sudo sed -i "s|CALICO_NODE_IMAGE|${CALICO_NODE_IMAGE}|g" /etc/calico/calico.env
sudo sed -i "s|ETCD_LISTEN_PORT|${ETCD_LISTEN_PORT}|g" /etc/calico/calico.env
sudo sed -i "s/DETECT_IP_OUTPUT/$(/opt/mesosphere/bin/detect_ip)/g" /etc/calico/calico.env

sed "s/^/export /g" /etc/calico/calico.env | sudo tee /etc/calico/calico.env.export


#### etcd systemd unit file (for masters)
sudo tee /etc/etcd/dcos-etcd.service <<-'EOF'
[Unit]
Description=etcd
Documentation=https://github.com/coreos/etcd
Conflicts=etcd.service
Conflicts=etcd2.service

[Service]
Type=notify
Restart=always
RestartSec=5s
LimitNOFILE=40000
TimeoutStartSec=0

EnvironmentFile=/etc/etcd/etcd.env

# Listen on 0.0.0.0, advertise on IP address
ExecStart=/opt/etcd/etcd --name ${LOCAL_HOSTNAME} \
  --data-dir ${ETCD_DATA_DIR} \
  --listen-client-urls https://0.0.0.0:${ETCD_LISTEN_PORT} \
  --advertise-client-urls https://${LOCAL_HOSTNAME}:${ETCD_LISTEN_PORT} \
  --listen-peer-urls https://0.0.0.0:${ETCD_TRANSPORT_PORT} \
  --initial-advertise-peer-urls https://${LOCAL_HOSTNAME}:${ETCD_TRANSPORT_PORT} \
  --initial-cluster ${INITIAL_CLUSTER} \
  --initial-cluster-token tkn \
  --initial-cluster-state new \
  --client-cert-auth \
  --trusted-ca-file ${ETCD_CERTS_DIR}/${ETCD_CA_CERT} \
  --cert-file ${ETCD_CERTS_DIR}/${ETCD_TLS_CERT} \
  --key-file ${ETCD_CERTS_DIR}/${ETCD_TLS_KEY} \
  --peer-client-cert-auth \
  --peer-trusted-ca-file ${ETCD_CERTS_DIR}/${ETCD_CA_CERT} \
  --peer-cert-file ${ETCD_CERTS_DIR}/${ETCD_TLS_CERT} \
  --peer-key-file ${ETCD_CERTS_DIR}/${ETCD_TLS_KEY}

[Install]
WantedBy=multi-user.target
EOF

#### etcd systemd unit file (for masters)
sudo tee /etc/etcd/dcos-etcd-open.service <<-'EOF'
[Unit]
Description=etcd
Documentation=https://github.com/coreos/etcd
Conflicts=etcd.service
Conflicts=etcd2.service

[Service]
Type=notify
Restart=always
RestartSec=5s
LimitNOFILE=40000
TimeoutStartSec=0

EnvironmentFile=/etc/etcd/etcd.env

# Listen on 0.0.0.0, advertise on IP address
ExecStart=/opt/etcd/etcd --name ${LOCAL_HOSTNAME} \
  --data-dir ${ETCD_DATA_DIR} \
  --listen-client-urls http://0.0.0.0:${ETCD_LISTEN_PORT} \
  --advertise-client-urls http://${LOCAL_HOSTNAME}:${ETCD_LISTEN_PORT} \
  --listen-peer-urls http://0.0.0.0:${ETCD_TRANSPORT_PORT} \
  --initial-advertise-peer-urls http://${LOCAL_HOSTNAME}:${ETCD_TRANSPORT_PORT} \
  --initial-cluster ${INITIAL_CLUSTER_OPEN} \
  --initial-cluster-token tkn \
  --initial-cluster-state new

[Install]
WantedBy=multi-user.target
EOF

#### etcd-proxy systemd unit file (for slaves)
sudo tee /etc/etcd/dcos-etcd-proxy.service <<-'EOF'
[Unit]
Description=etcd-proxy
Documentation=https://github.com/coreos/etcd
Conflicts=etcd.service
Conflicts=etcd2.service

[Service]
Type=notify
Restart=always
RestartSec=5s
LimitNOFILE=40000
TimeoutStartSec=0

EnvironmentFile=/etc/etcd/etcd.env

# Listen on 0.0.0.0, advertise on IP address
ExecStart=/opt/etcd/etcd --proxy on \
  --data-dir ${ETCD_DATA_DIR} \
  --listen-client-urls https://0.0.0.0:${ETCD_LISTEN_PORT} \
  --key-file ${ETCD_CERTS_DIR}/${ETCD_TLS_KEY} \
  --cert-file ${ETCD_CERTS_DIR}/${ETCD_TLS_CERT} \
  --peer-key-file ${ETCD_CERTS_DIR}/${ETCD_TLS_KEY} \
  --peer-cert-file ${ETCD_CERTS_DIR}/${ETCD_TLS_CERT} \
  --trusted-ca-file ${ETCD_CERTS_DIR}/${ETCD_CA_CERT} \
  --peer-trusted-ca-file ${ETCD_CERTS_DIR}/${ETCD_CA_CERT} \
  --client-cert-auth \
  --peer-client-cert-auth \
  --initial-cluster ${INITIAL_CLUSTER}

[Install]
WantedBy=multi-user.target
EOF

#### etcd-proxy systemd unit file (for slaves)
sudo tee /etc/etcd/dcos-etcd-proxy-open.service <<-'EOF'
[Unit]
Description=etcd-proxy
Documentation=https://github.com/coreos/etcd
Conflicts=etcd.service
Conflicts=etcd2.service

[Service]
Type=notify
Restart=always
RestartSec=5s
LimitNOFILE=40000
TimeoutStartSec=0

EnvironmentFile=/etc/etcd/etcd.env

# Listen on 0.0.0.0, advertise on IP address
ExecStart=/opt/etcd/etcd --proxy on \
  --data-dir ${ETCD_DATA_DIR} \
  --listen-client-urls http://0.0.0.0:${ETCD_LISTEN_PORT} \
  --initial-cluster ${INITIAL_CLUSTER_OPEN}

[Install]
WantedBy=multi-user.target
EOF


#### calico node (Docker container) systemd unit file
sudo tee /etc/calico/dcos-calico-node.service <<-'EOF'
[Unit]
Description=calico-node
After=docker.service
Requires=docker.service

[Service]
EnvironmentFile=/etc/calico/calico.env
ExecStartPre=-/usr/bin/docker rm -f calico-node
ExecStart=/usr/bin/docker run --net=host --privileged \
 --name=calico-node \
 -e NODENAME=${CALICO_NODENAME} \
 -e IP=${CALICO_IP} \
 -e IP6=${CALICO_IP6} \
 -e CALICO_NETWORKING_BACKEND=${CALICO_NETWORKING_BACKEND} \
 -e AS=${CALICO_AS} \
 -e NO_DEFAULT_POOLS=${CALICO_NO_DEFAULT_POOLS} \
 -e CALICO_LIBNETWORK_ENABLED=${CALICO_LIBNETWORK_ENABLED} \
 -e CALICO_LIBNETWORK_LABEL_ENDPOINTS=true \
 -e ETCD_ENDPOINTS=${ETCD_ENDPOINTS} \
 -e ETCD_CA_CERT_FILE=${ETCD_CONTAINER_CERT_DIR}/${ETCD_CA_CERT_FILE} \
 -e ETCD_CERT_FILE=${ETCD_CONTAINER_CERT_DIR}/${ETCD_CERT_FILE} \
 -e ETCD_KEY_FILE=${ETCD_CONTAINER_CERT_DIR}/${ETCD_KEY_FILE} \
 -e FELIX_IGNORELOOSERPF=true \
 -v ${ETCD_CERT_DIR}:${ETCD_CONTAINER_CERT_DIR} \
 -v /var/log/calico:/var/log/calico \
 -v /run/docker/plugins:/run/docker/plugins \
 -v /lib/modules:/lib/modules \
 -v /var/run/calico:/var/run/calico \
 -v /var/run/docker.sock:/var/run/docker.sock \
 ${CALICO_DOCKER_IMAGE}

# Need FELIX_IGNORELOOSERPF for DC/OS, see https://github.com/projectcalico/calicoctl/issues/1082
# Need /var/run/docker.sock to connect to host Docker socket from within container

ExecStop=-/usr/bin/docker stop calico-node

Restart=always
StartLimitBurst=3
StartLimitInterval=60s

[Install]
WantedBy=multi-user.target
EOF

#### calico node (Docker container) systemd unit file
sudo tee /etc/calico/dcos-calico-node-open.service <<-'EOF'
[Unit]
Description=calico-node
After=docker.service
Requires=docker.service

[Service]
EnvironmentFile=/etc/calico/calico.env
ExecStartPre=-/usr/bin/docker rm -f calico-node
ExecStart=/usr/bin/docker run --net=host --privileged \
 --name=calico-node \
 -e NODENAME=${CALICO_NODENAME} \
 -e IP=${CALICO_IP} \
 -e IP6=${CALICO_IP6} \
 -e CALICO_NETWORKING_BACKEND=${CALICO_NETWORKING_BACKEND} \
 -e AS=${CALICO_AS} \
 -e NO_DEFAULT_POOLS=${CALICO_NO_DEFAULT_POOLS} \
 -e CALICO_LIBNETWORK_ENABLED=${CALICO_LIBNETWORK_ENABLED} \
 -e CALICO_LIBNETWORK_LABEL_ENDPOINTS=true \
 -e ETCD_ENDPOINTS=${ETCD_ENDPOINTS_OPEN} \
 -e FELIX_IGNORELOOSERPF=true \
 -v /var/log/calico:/var/log/calico \
 -v /run/docker/plugins:/run/docker/plugins \
 -v /lib/modules:/lib/modules \
 -v /var/run/calico:/var/run/calico \
 -v /var/run/docker.sock:/var/run/docker.sock \
 ${CALICO_DOCKER_IMAGE}

# Need FELIX_IGNORELOOSERPF for DC/OS, see https://github.com/projectcalico/calicoctl/issues/1082
# Need /var/run/docker.sock to connect to host Docker socket from within container

ExecStop=-/usr/bin/docker stop calico-node

Restart=always
StartLimitBurst=3
StartLimitInterval=60s

[Install]
WantedBy=multi-user.target
EOF


#### calico node (Docker container) systemd timer file
sudo tee /etc/calico/dcos-calico-node.timer <<-'EOF'
[Unit]
Description=Ensure Calico Node is running

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
EOF


#### calico node (Docker container) systemd timer file
sudo tee /etc/calico/dcos-calico-node-open.timer <<-'EOF'
[Unit]
Description=Ensure Calico Node is running

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
EOF
