#!/bin/bash
INFO_REALM=${1:-all}

echo "==== STATS FOR: "$(/opt/mesosphere/bin/detect_ip)

if [ "${INFO_REALM}" = "all" ] || [ "${INFO_REALM}" = "zookeeper" ]; then
#echo "--- ZOOKEEPER ---"

# shortened list (one liner) of all ensemble members
ZOOKEEPER_SHORT_ENSEMBLE_STATUS=$(curl -fsSL http://localhost:8181/exhibitor/v1/cluster/status | jq -r '.[] | .hostname +"|"+ .description +";"' | tr -d '\n')
# get the current Zookeeper leader
ZOOKEEPER_LEADER=$(curl -fsSL http://localhost:8181/exhibitor/v1/cluster/status | jq '.[] | select(.isLeader == true) | .hostname' | tr -d '"')
# get the current Zxid from the local Zookeeper instance (via Exhibitor API)
ZOOKEEPER_TRANSACTION_ID=$(echo -e $(curl -fsSL http://localhost:8181/exhibitor/v1/cluster/4ltr/srvr) | grep Zxid | cut -d":" -f 2)
# get the current znode count from the local Zookeeper instance (via Exhibitor API)
ZOOKEEPER_ZNODE_COUNT=$(echo -e $(curl -fsSL http://localhost:8181/exhibitor/v1/cluster/4ltr/srvr) | grep "Node count" | cut -d":" -f 2)
# TODO: (NEEDED?)
ZOOKEEPER_LOG_FOLDER=$(ls -lth /var/lib/dcos/exhibitor/zookeeper/transactions/version-2 | grep log)
# TODO: (NEEDED?)
#ZOOKEEPER_LOG_FOLDER_SIZE=$(du -sh /var/lib/dcos/exhibitor/zookeeper/transactions/version-2)

# TODO: add check that Zookeeper/Exhibitor is not running (e.g. using systemctl) -> maybe not needed, since the rest sees it as down

echo "ZK:: ID: "$(cat /var/lib/dcos/exhibitor/zookeeper/snapshot/myid)", CURRENT_EPOCH: "$(cat /var/lib/dcos/exhibitor/zookeeper/snapshot/version-2/currentEpoch)", ACCEPTED_EPOCH: "$(cat /var/lib/dcos/exhibitor/zookeeper/snapshot/version-2/acceptedEpoch)
echo "ZK:: ENSEMBLE: "${ZOOKEEPER_SHORT_ENSEMBLE_STATUS}
echo "ZK:: LEADER: "${ZOOKEEPER_LEADER}
echo "ZK:: CURRENT_ZXID: "${ZOOKEEPER_TRANSACTION_ID}", CURRENT_ZNODE_COUNT: "${ZOOKEEPER_ZNODE_COUNT}
#echo "LOG_FOLDER:"${ZOOKEEPER_LOG_FOLDER}
fi

if [ "${INFO_REALM}" = "all" ] || [ "${INFO_REALM}" = "mesos" ]; then
#echo ""
#echo "--- MESOS ---"
REGISTRAR_LOG_RECOVERED=$(curl -fsSL http://$(/opt/mesosphere/bin/detect_ip):5050/metrics/snapshot | jq '.["registrar/log/recovered"]')
LEADER=$(curl -fsSL http://$(/opt/mesosphere/bin/detect_ip):5050/state | jq -r '.leader_info.hostname')

echo "MESOS:: REGISTRAR_LOG_RECOVERED: "${REGISTRAR_LOG_RECOVERED}
echo "MESOS:: CURRENT_LEADER: "${LEADER}
fi

#echo ""
#echo "--- COCKROACH ---"
if [ "${INFO_REALM}" = "all" ] || [ "${INFO_REALM}" = "cockroach" ]; then
echo "COCKROACH:: "
sudo /opt/mesosphere/bin/cockroach node status --format csv --ranges --certs-dir=/run/dcos/pki/cockroach --host=$(/opt/mesosphere/bin/detect_ip) | rev | cut -d',' -f 1,2,3,4,5,9,10 | rev | grep -v rows | grep -v id
fi

#echo ""
#echo ""
echo "===="
