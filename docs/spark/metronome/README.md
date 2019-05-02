# Run Spark Jobs in Client Mode with Metronome

* Setup service account and secret

```bash
dcos security org service-accounts keypair /tmp/spark-private.pem /tmp/spark-public.pem
dcos security org service-accounts create -p /tmp/spark-public.pem -d "Spark service account" spark-principal
dcos security secrets create-sa-secret --strict /tmp/spark-private.pem spark-principal spark-pi/secret
```

* Grant permissions to the Spark service account

```bash
dcos security org users grant spark-principal dcos:mesos:agent:task:user:root create
dcos security org users grant spark-principal "dcos:mesos:master:framework:role:*" create
dcos security org users grant spark-principal dcos:mesos:master:task:app_id:/spark-pi create
dcos security org users grant spark-principal dcos:mesos:master:task:user:nobody create
```

* Create a file `/tmp/spark-pi-metronome.json` with the job definition

```json
{
    "id": "spark-pi",
    "description": "Spark PI",
    "run": {
      "cpus": 1,
      "mem": 1024,
      "disk": 0,
      "cmd": "/opt/spark/bin/spark-submit --master ${SPARK_MASTER_URL} --conf spark.app.name=${SPARK_NAME} --conf spark.mesos.containerizer=${MESOS_CONTAINERIZER} --conf spark.mesos.principal=${MESOS_PRINCIPAL} --conf spark.mesos.role=${MESOS_ROLE} --conf spark.mesos.driverEnv.SPARK_USER=${SPARK_USER} --conf spark.driver.cores=${SPARK_DRIVER_CORES} --conf spark.driver.memory=${SPARK_DRIVER_MEM} --conf spark.cores.max=${SPARK_CORES_MAX} --conf spark.mesos.executor.docker.image=${SPARK_DOCKER_IMAGE} --conf spark.mesos.executor.home=${SPARK_EXECUTOR_HOME} --conf spark.executor.cores=${SPARK_EXECUTOR_CORES} --conf spark.executor.memory=${SPARK_EXECUTOR_MEM}  --conf spark.mesos.uris=${SPARK_URIS} --class ${SPARK_CLASS} ${MESOS_SANDBOX}/${SPARK_JAR} ${SPARK_ARGS}",
      "user": "nobody",
      "env": {
        "DCOS_SERVICE_ACCOUNT_CREDENTIAL": {
              "secret": "secret0"
        },
        "SPARK_NAME": "pi",
        "MESOS_CONTAINERIZER": "mesos",
        "MESOS_PRINCIPAL": "spark-principal",
        "MESOS_ROLE": "*",
        "SPARK_MASTER_URL": "mesos://zk://zk-1.zk:2181,zk-2.zk:2181,zk-3.zk:2181,zk-4.zk:2181,zk-5.zk:2181/mesos",
        "SPARK_USER": "nobody",
        "SPARK_DRIVER_CORES": "1",
        "SPARK_DRIVER_MEM": "512m",
        "SPARK_CORES_MAX": "2",
        "SPARK_DOCKER_IMAGE": "mesosphere/spark:2.8.0-2.4.0-hadoop-2.9",
        "SPARK_EXECUTOR_HOME": "/opt/spark/",
        "SPARK_EXECUTOR_CORES": "2",
        "SPARK_EXECUTOR_MEM": "512m",
        "SPARK_CLASS": "org.apache.spark.examples.SparkPi",
        "SPARK_URIS": "https://downloads.mesosphere.com/spark/assets/spark-examples_2.11-2.4.0.jar",
        "SPARK_JAR": "spark-examples_2.11-2.4.0.jar",
        "SPARK_ARGS": "30"
      },
      "secrets": {
        "secret0": {
          "source": "spark-pi/secret"
        }
      },  
      "placement": {
        "constraints": []
      },
      "artifacts": [
        {
          "uri": "https://downloads.mesosphere.com/spark/assets/spark-examples_2.11-2.4.0.jar",
          "extract": false,
          "executable": false,
          "cache": true
        }
      ],
      "maxLaunchDelay": 3600,
      "docker": {
        "image": "mesosphere/spark:2.8.0-2.4.0-hadoop-2.9"
      },
      "restart": {
        "policy": "NEVER"
      }
    },
    "schedules": []
}
```

* Add the Spark job

```bash
$ dcos job add /tmp/spark-pi-metronome.json
$ dcos job run spark-pi
20190502145959Agly4
$ dcos task log --completed pi_20190502145959Agly4
Pi is roughly 3.141781047260349
```