# Spark Streaming Job with CNI

## Set Calico Policies for Spark and Kafka

The default profile doesn't allow the Host to connect to Calico IP addresses. But in order for starting a Spark Job and Kafka scheduler, it must be able to talk to Mesos Masters.

To discover the IP address assigned for the Calico Tunnel run something like the following on the Mesos Masters:

```shell
$ ip addr show tunl0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1
172.16.118.192
```

- Define this IP address within the Calico Policy for Spark and apply it via:

```yaml
calicoctl apply -f - <<EOF
apiVersion: v1
kind: policy
metadata:
  name: allow-spark
spec:
  selector: role == 'spark'
  egress:
  - action: allow
    destination: {}
    source: {}
  ingress:
  - action: allow
    destination: {}
    source:
      selector: role == 'spark'
  - action: allow
    destination: {}
    source:
      selector: role == 'kafka'
  - action: allow
    destination: {}
    source:
      nets:
        - "172.16.118.192/32"
EOF
```

- Define this IP address within the Calico Policy for Kafka and apply it via:

```yaml
calicoctl apply -f - <<EOF
apiVersion: v1
kind: policy
metadata:
  name: allow-kafka
spec:
  selector: role == 'kafka'
  egress:
  - action: allow
    destination: {}
    source: {}
  ingress:
  - action: allow
    destination: {}
    source:
      selector: role == 'spark'
  - action: allow
    destination: {}
    source:
      selector: role == 'kafka'
  - action: allow
    destination: {}
    source:
      nets:
        - "172.16.118.192/32"
EOF
```

## Setup Kafka

https://docs.mesosphere.com/services/kafka/kafka-auth/

- Install Enterprise CLI

```shell
dcos package install dcos-enterprise-cli --cli --yes
```

- For this demo install Kafka in Strict Mode

```shell
dcos security org service-accounts keypair /tmp/kafka-private-key.pem /tmp/kafka-public-key.pem
dcos security org service-accounts create -p /tmp/kafka-public-key.pem -d "Kafka service account" kafka-principal
dcos security secrets create-sa-secret --strict /tmp/kafka-private-key.pem kafka-principal kafka/secret
```

- Grant permissions to Kafka

```shell
dcos security org users grant kafka-principal dcos:mesos:master:framework:role:kafka-role create
dcos security org users grant kafka-principal dcos:mesos:master:reservation:role:kafka-role create
dcos security org users grant kafka-principal dcos:mesos:master:volume:role:kafka-role create
dcos security org users grant kafka-principal dcos:mesos:master:task:user:nobody create
dcos security org users grant kafka-principal dcos:mesos:master:reservation:principal:kafka-principal delete
dcos security org users grant kafka-principal dcos:mesos:master:volume:principal:kafka-principal delete
```

## Install Kafka

- Create Kafka configuration file

```shell
cat <<EOF > /tmp/kafka.json
{
  "service": {
    "name": "kafka",
    "user": "nobody",
    "service_account": "kafka-principal",
    "service_account_secret": "kafka/secret",
    "virtual_network_enabled": true,
    "virtual_network_name": "calico",
    "virtual_network_plugin_labels": "role:kafka"
  }
}
EOF
```

- Install Kafka

```shell
dcos package install --options=/tmp/kafka.json kafka --yes
```

- Check that Kafka brokers are using the Calico IP addresses

```shell
$ dcos kafka endpoints broker
{
  "address": [
    "172.16.30.1:1025",
    "172.16.140.129:1025",
    "172.16.227.1:1025"
  ],
  "dns": [
    "kafka-0-broker.kafka.autoip.dcos.thisdcos.directory:1025",
    "kafka-1-broker.kafka.autoip.dcos.thisdcos.directory:1025",
    "kafka-2-broker.kafka.autoip.dcos.thisdcos.directory:1025"
  ],
  "vip": "broker.kafka.l4lb.thisdcos.directory:9092"
}
```

- Setup a topic

```shell
dcos kafka topic create mytopic --replication=2 --partitions=4
```

## Install Spark

- Setup service account and secret

```shell
dcos security org service-accounts keypair /tmp/spark-private.pem /tmp/spark-public.pem
dcos security org service-accounts create -p /tmp/spark-public.pem -d "Spark service account" spark-principal
dcos security secrets create-sa-secret --strict /tmp/spark-private.pem spark-principal spark/secret
```

- Grant permissions to the Spark

```shell
dcos security org users grant spark-principal dcos:mesos:agent:task:user:root create
dcos security org users grant spark-principal "dcos:mesos:master:framework:role:*" create
dcos security org users grant spark-principal dcos:mesos:master:task:app_id:/spark create
dcos security org users grant spark-principal dcos:mesos:master:task:user:nobody create
dcos security org users grant spark-principal dcos:mesos:master:task:user:root create
```

- Grant permissions to Marathon in order to the Spark the dispatcher in root

```shell
dcos security org users grant dcos_marathon dcos:mesos:master:task:user:root create
```

- Create a configuration file **/tmp/spark.json** and set the Spark principal and secret

```json
cat <<EOF > /tmp/spark.json
{
  "service": {
    "name": "spark",
    "service_account": "spark-principal",
    "service_account_secret": "spark/secret",
    "user": "nobody",
    "virtual_network_enabled": true,
    "virtual_network_name": "calico",
    "virtual_network_plugin_labels": [{
      "key":"role",
      "value": "spark"
    }],
    "UCR_containerizer": true,
    "docker_user": "99"
  }
}
EOF
```

- Install Spark using the configuration file

```shell
dcos package install spark --options=/tmp/spark.json --package-version 2.7.0-2.4.0 --yes
```

## Run Spark Streaming Job

```shell
dcos spark run --verbose --submit-args="--supervise --conf spark.mesos.network.name=calico --conf spark.mesos.network.labels=role:spark --conf spark.mesos.containerizer=mesos --conf spark.mesos.driverEnv.SPARK_USER=nobody --conf spark.cores.max=6 --conf spark.mesos.executor.docker.image=janr/spark-streaming-kafka:2.7.0-2.4.0-hadoop-2.7-nobody-99 --conf spark.mesos.executor.docker.forcePullImage=true https://gist.githubusercontent.com/jrx/56e72ada489bf36646525c34fdaa7d63/raw/90df6046886e7c50fb18ea258a7be343727e944c/streamingWordCount-CNI.py"
```

## Test connection

- Run the following on the master node

```shell
docker run -ti ches/kafka kafka-console-producer.sh --topic mytopic --broker-list kafka-0-broker.kafka.autoip.dcos.thisdcos.directory:1025
```

- Start a container `kafka-producer` with the Calico role `kafka` that will be used to send messages to the brokers

```json
cat <<EOF > /tmp/kafka-producer.json
{
  "id": "/kafka-producer",
  "user": "root",
  "cmd": "while true; do echo 'Kafka-Producer'; sleep 60; done",
  "container": {
    "type": "MESOS",
    "docker": {
      "image": "ches/kafka"
    }
  },
  "cpus": 0.5,
  "instances": 1,
  "mem": 256,
  "networks": [
    {
      "name": "calico",
      "mode": "container",
      "labels": {
        "role": "kafka"
      }
    }
  ]
}
EOF
```

```shell
dcos marathon app add /tmp/kafka-producer.json
```

- We jump into the container `kafka-producer` and try to send some stuff to Kafka:

```shell
$ dcos task exec -it kafka-producer /kafka/bin/kafka-console-producer.sh --topic mytopic --broker-list kafka-0-broker.kafka.autoip.dcos.thisdcos.directory:1025
Overwriting environment variable 'LIBPROCESS_IP'
Hello World
```