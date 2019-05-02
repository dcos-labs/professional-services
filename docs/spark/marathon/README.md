# Run Spark Streaming Job in Client Mode with Marathon

* Setup service account and secret

```bash
dcos security org service-accounts keypair /tmp/spark-private.pem /tmp/spark-public.pem
dcos security org service-accounts create -p /tmp/spark-public.pem -d "Spark service account" spark-principal
dcos security secrets create-sa-secret --strict /tmp/spark-private.pem spark-principal spark-networkcount/secret
```

* Grant permissions to the Spark service account

```bash
dcos security org users grant spark-principal dcos:mesos:agent:task:user:root create
dcos security org users grant spark-principal "dcos:mesos:master:framework:role:*" create
dcos security org users grant spark-principal dcos:mesos:master:task:app_id:/spark-networkcount create
dcos security org users grant spark-principal dcos:mesos:master:task:user:nobody create
```

* Create a file `/tmp/spark-networkcount-marathon.json` with the following app definition

```json
{
  "env": {
    "DCOS_SERVICE_ACCOUNT_CREDENTIAL": {
      "secret": "secret0"
    },
    "SPARK_NAME": "spark-networkcount",
    "MESOS_CONTAINERIZER": "mesos",
    "MESOS_PRINCIPAL": "spark-principal",
    "MESOS_ROLE": "*",
    "SPARK_MASTER_URL": "mesos://zk://zk-1.zk:2181,zk-2.zk:2181,zk-3.zk:2181,zk-4.zk:2181,zk-5.zk:2181/mesos",
    "SPARK_DRIVER_CORES": "1",
    "SPARK_DRIVER_MEM": "512m",
    "SPARK_CORES_MAX": "2",
    "SPARK_DOCKER_IMAGE": "mesosphere/spark:2.8.0-2.4.0-hadoop-2.9",
    "SPARK_EXECUTOR_HOME": "/opt/spark",
    "SPARK_EXECUTOR_CORES": "2",
    "SPARK_EXECUTOR_MEM": "512m",
    "SPARK_CLASS": "org.apache.spark.examples.streaming.JavaNetworkWordCount",
    "SPARK_JAR": "spark-examples_2.11-2.4.0.jar",
    "SPARK_USER": "nobody",
    "SPARK_ARGS": "leader.mesos 61091"
  },
  "labels": {
    "MARATHON_SINGLE_INSTANCE_APP": "true"
  },
  "id": "/spark-networkcount",
  "backoffFactor": 1.15,
  "backoffSeconds": 1,
  "cmd": "/opt/spark/bin/spark-submit --master ${SPARK_MASTER_URL} --conf spark.app.name=${SPARK_NAME} --conf spark.mesos.containerizer=${MESOS_CONTAINERIZER} --conf spark.mesos.principal=${MESOS_PRINCIPAL} --conf spark.mesos.role=${MESOS_ROLE} --conf spark.mesos.driverEnv.SPARK_USER=${SPARK_USER} --conf spark.driver.cores=${SPARK_DRIVER_CORES} --conf spark.driver.memory=${SPARK_DRIVER_MEM} --conf spark.cores.max=${SPARK_CORES_MAX} --conf spark.mesos.executor.docker.image=${SPARK_DOCKER_IMAGE} --conf spark.mesos.executor.home=${SPARK_EXECUTOR_HOME} --conf spark.executor.cores=${SPARK_EXECUTOR_CORES} --conf spark.executor.memory=${SPARK_EXECUTOR_MEM} --class ${SPARK_CLASS} ${MESOS_SANDBOX}/${SPARK_JAR} ${SPARK_ARGS}",
  "container": {
    "type": "MESOS",
    "volumes": [],
    "docker": {
      "image": "mesosphere/spark:2.8.0-2.4.0-hadoop-2.9",
      "forcePullImage": false,
      "parameters": []
    }
  },
  "cpus": 1,
  "disk": 0,
  "fetch": [
    {
      "uri": "https://downloads.mesosphere.com/spark/assets/spark-examples_2.11-2.4.0.jar",
      "extract": false,
      "executable": false,
      "cache": true
    }
  ],
  "instances": 1,
  "maxLaunchDelaySeconds": 3600,
  "mem": 1024,
  "gpus": 0,
  "networks": [
    {
      "mode": "host"
    }
  ],
  "portDefinitions": [
    {
      "labels": {
        "VIP_0": "/spark-networkcount:4040"
      },
      "name": "driver-ui",
      "protocol": "tcp",
      "port": 0
    }
  ],
  "requirePorts": false,
  "secrets": {
    "secret0": {
      "source": "spark-networkcount/secret"
    }
  },
  "upgradeStrategy": {
    "maximumOverCapacity": 0,
    "minimumHealthCapacity": 0
  },
  "user": "nobody",
  "killSelection": "YOUNGEST_FIRST",
  "unreachableStrategy": {
    "inactiveAfterSeconds": 0,
    "expungeAfterSeconds": 0
  },
  "healthChecks": [],
  "constraints": []
}
```

* Add the Spark app

```bash
$ dcos marathon app add /tmp/spark-networkcount-marathon.json
```