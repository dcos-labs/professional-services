# Streaming Job via Spark Dispatcher

## 1. Install Spark in Strict Mode

- Setup Spark service account and secret

```shell
dcos security org service-accounts keypair /tmp/spark-private.pem /tmp/spark-public.pem
dcos security org service-accounts create -p /tmp/spark-public.pem -d "Spark service account" spark-principal
dcos security secrets create-sa-secret --strict /tmp/spark-private.pem spark-principal spark/secret
```

- Grant permissions to the service account

```shell
dcos security org users grant spark-principal "dcos:mesos:master:framework:role:*" create
dcos security org users grant spark-principal dcos:mesos:master:task:app_id:/spark create
dcos security org users grant spark-principal dcos:mesos:master:task:user:nobody create
dcos security org users grant spark-principal dcos:mesos:agent:task:user:nobody create
```

- Create a configuration file **/tmp/spark.json**

```json
cat <<EOF > /tmp/spark.json
{
  "service": {
    "name": "spark",
    "service_account": "spark-principal",
    "service_account_secret": "spark/secret",
    "user": "nobody",
    "UCR_containerizer": true,
    "docker_user": "99"
  }
}
EOF
```

- Install Spark referencing the configuration file

```shell
dcos package install spark --options=/tmp/spark.json --package-version 2.8.0-2.4.0 --yes
```

## 2. Install Kafka

For this demo we will make use of Kafka.

- Setup a service account and secret

```shell
dcos security org service-accounts keypair /tmp/kafka-private-key.pem /tmp/kafka-public-key.pem
dcos security org service-accounts create -p /tmp/kafka-public-key.pem -d "Kafka service account" kafka-principal
dcos security secrets create-sa-secret --strict /tmp/kafka-private-key.pem kafka-principal kafka/secret
```

- Grant permissions to the Kafka service account

```shell
dcos security org users grant kafka-principal dcos:mesos:master:framework:role:kafka-role create
dcos security org users grant kafka-principal dcos:mesos:master:reservation:role:kafka-role create
dcos security org users grant kafka-principal dcos:mesos:master:volume:role:kafka-role create
dcos security org users grant kafka-principal dcos:mesos:master:task:user:nobody create
dcos security org users grant kafka-principal dcos:mesos:master:reservation:principal:kafka-principal delete
dcos security org users grant kafka-principal dcos:mesos:master:volume:principal:kafka-principal delete
```

- Create a Kafka configuration file **/tmp/kafka.json**

```shell
cat <<EOF > /tmp/kafka.json
{
  "service": {
    "name": "kafka",
    "user": "nobody",
    "service_account": "kafka-principal",
    "service_account_secret": "kafka/secret"
  }
}
EOF
```

- Install Kafka

```shell
dcos package install kafka --options=/tmp/kafka.json --package-version 2.5.0-2.1.0
```

- Setup a topic

```shell
dcos kafka topic create mytopic --replication=2 --partitions=4
```

## 3. Submit Spark Streaming Job

- Submit a long running Job and set the flag `--supervise` to automatically restart the driver, if it's failing

```shell
dcos spark run --verbose --submit-args=" \
--supervise \
--conf spark.app.name=wordcount \
--conf spark.mesos.containerizer=mesos \
--conf spark.mesos.principal=spark-principal \
--conf spark.mesos.driverEnv.SPARK_USER=nobody \
--conf spark.cores.max=6 \
--conf spark.mesos.executor.docker.image=mesosphere/spark:2.8.0-2.4.0-hadoop-2.9 \
--conf spark.mesos.executor.docker.forcePullImage=true \
--jars http://central.maven.org/maven2/org/apache/spark/spark-streaming-kafka-0-8-assembly_2.11/2.2.3/spark-streaming-kafka-0-8-assembly_2.11-2.2.3.jar \
https://gist.githubusercontent.com/jrx/fb99c6c8d74b8e86c16e609803072726/raw/d3e4c93e0e1a1e8f4305c7fc6b4f5041e2762a73/streamingWordCount.py"
```

- Jump into the container of the Spark driver and kill all processes

```shell
dcos task exec -it driver-20190510154227-0002 bash
kill -9 -1
```

The driver should be automatically restarted.

- You can kill the driver by running:

```shell
dcos spark kill driver-20190510154227-0002
```
