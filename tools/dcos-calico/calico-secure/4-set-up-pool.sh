source 1a-env.export.sh

# This should only be run on one master
sudo calicoctl get ipps -o json | sudo tee /etc/calico/ippool-backup.json
sudo calicoctl delete -f /etc/calico/ippool-backup.json
#sudo calicoctl delete ipps 192.168.0.0/16

total=${#CALICO_NAME[*]}

for (( i=0; i<=$(( $total -1 )); i++ ))
do 

sudo calicoctl apply -f /etc/calico/ippool-${CALICO_NAME[$i]}.json
sudo calicoctl get ipps -o json

### Set up Docker network
sudo docker network rm ${CALICO_NAME[$i]}
sudo docker network create --driver calico --ipam-driver calico-ipam --subnet=${CALICO_CIDR[$i]} ${CALICO_NAME[$i]}

done

sudo docker network ls