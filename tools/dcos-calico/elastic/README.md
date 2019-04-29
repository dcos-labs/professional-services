# Elastic + Kibana

## Set Calico Policies for Elastic and Kibana

The default profile doesn't allow the Host to connect to Calico IP addresses. But in order for starting a the Elastic scheduler, it must be able to talk to the Mesos Masters.

To discover the IP address assigned for the Calico Tunnel run something like the following on the Mesos Masters:

```
$ ip addr show tunl0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1
192.168.230.192
```

- Define this IP address within the Calico Policy for Elastic and apply it via:

```yaml
calicoctl apply -f - <<EOF
apiVersion: v1
kind: policy
metadata:
  name: allow-elastic
spec:
  selector: role == 'elastic'
  egress:
  - action: allow
    destination: {}
    source: {}
  ingress:
  - action: allow
    destination: {}
    source:
      selector: role == 'kibana'
  - action: allow
    destination: {}
    source:
      selector: role == 'elastic'
  - action: allow
    destination: {}
    source:
      nets:
        - "192.168.230.192/32"
EOF
```

- Define this IP address within the Calico Policy for Kibana and apply it via:

```yaml
calicoctl apply -f - <<EOF
apiVersion: v1
kind: policy
metadata:
  name: allow-kibana
spec:
  selector: role == 'kibana'
  egress:
  - action: allow
    destination: {}
    source: {}
  ingress:
  - action: allow
    destination: {}
    source:
      selector: role == 'kibana'
  - action: allow
    destination: {}
    source:
      nets:
        - "192.168.230.192/32"
EOF
```

## Setup Elastic

https://docs.mesosphere.com/services/elastic/elastic-auth/

- Install Enterprise CLI

```
dcos package install dcos-enterprise-cli --cli --yes
```

- For this demo install Elastic in Strict Mode

```
dcos security org service-accounts keypair /tmp/elastic-private-key.pem /tmp/elastic-public-key.pem
dcos security org service-accounts create -p /tmp/elastic-public-key.pem -d "Elastic service account" elastic-principal
dcos security secrets create-sa-secret --strict /tmp/elastic-private-key.pem elastic-principal elastic/secret
```

- Create permissions for Elastic

```
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:framework:role:elastic-role \
-d '{"description":"Controls the ability of elastic-role to register as a framework with the Mesos master"}' \
-H 'Content-Type: application/json'
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:reservation:role:elastic-role \
-d '{"description":"Controls the ability of elastic-role to reserve resources"}' \
-H 'Content-Type: application/json'
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:volume:role:elastic-role \
-d '{"description":"Controls the ability of elastic-role to access volumes"}' \
-H 'Content-Type: application/json'
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:reservation:principal:elastic-principal \
-d '{"description":"Controls the ability of elastic-principal to reserve resources"}' \
-H 'Content-Type: application/json'
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:volume:principal:elastic-principal \
-d '{"description":"Controls the ability of elastic-principal to access volumes"}' \
-H 'Content-Type: application/json'
```

- Grant Permissions to Elastic

```
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:framework:role:elastic-role/users/elastic-principal/create
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:reservation:role:elastic-role/users/elastic-principal/create
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:volume:role:elastic-role/users/elastic-principal/create
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:task:user:nobody/users/elastic-principal/create
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:reservation:principal:elastic-principal/users/elastic-principal/delete
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:volume:principal:elastic-principal/users/elastic-principal/delete
```

## Install Elastic

- Create Elastic configuration file

```
cat <<EOF > /tmp/elastic.json
{
  "service": {
    "name": "elastic",
    "user": "nobody",
    "service_account": "elastic-principal",
    "service_account_secret": "elastic/secret",
    "virtual_network_enabled": true,
    "virtual_network_name": "calico",
    "virtual_network_plugin_labels": "role:elastic"
  }
}
EOF
```

- Install Elastic

```
dcos package install --options=/tmp/elastic.json elastic
```

- Check that Elastic is using the Calico IP addresses

```
dcos elastic endpoints coordinator-http
{
  "address": ["192.168.252.130:1025"],
  "dns": ["coordinator-0-node.elastic.autoip.dcos.thisdcos.directory:1025"],
  "vip": "coordinator.elastic.l4lb.thisdcos.directory:9200"
}
```

## Install Kibana

We need to modify the default configuration of the Kibana package so it's able to start with a CNI IP addresse:

```
{
  "id": "/kibana",
  "backoffFactor": 1.15,
  "backoffSeconds": 1,
  "cmd": "echo -e \"elasticsearch.url: $ELASTICSEARCH_URL\nelasticsearch.username: $KIBANA_USER\nelasticsearch.password: $KIBANA_PASSWORD\nserver.host: 0.0.0.0\nserver.port: $PORT_KIBANA\" > $MESOS_SANDBOX/kibana-$ELASTIC_VERSION-linux-x86_64/config/kibana.yml; if [ \"$XPACK_ENABLED\" = true ]; then echo -e \"\nxpack.security.encryptionKey: $MESOS_FRAMEWORK_ID\nxpack.reporting.encryptionKey: $MESOS_FRAMEWORK_ID\n\" >> $MESOS_SANDBOX/kibana-$ELASTIC_VERSION-linux-x86_64/config/kibana.yml; echo 'Installing X-Pack plugin...'; $MESOS_SANDBOX/kibana-$ELASTIC_VERSION-linux-x86_64/bin/kibana-plugin install file://$MESOS_SANDBOX/x-pack-$ELASTIC_VERSION.zip; fi; env && $MESOS_SANDBOX/kibana-$ELASTIC_VERSION-linux-x86_64/bin/kibana",
  "container": {
    "type": "MESOS",
    "volumes": []
  },
  "cpus": 0.5,
  "disk": 0,
  "env": {
    "ELASTICSEARCH_URL": "http://coordinator.elastic.l4lb.thisdcos.directory:9200",
    "FRAMEWORK_USER": "nobody",
    "KIBANA_PASSWORD": "changeme",
    "KIBANA_USER": "kibana",
    "XPACK_ENABLED": "false",
    "FRAMEWORK_NAME": "kibana",
    "ELASTIC_VERSION": "5.6.5",
    "PORT_KIBANA": "8080"
  },
  "fetch": [
    {
      "uri": "https://artifacts.elastic.co/downloads/kibana/kibana-5.6.5-linux-x86_64.tar.gz",
      "extract": true,
      "executable": false,
      "cache": false
    },
    {
      "uri": "https://artifacts.elastic.co/downloads/packs/x-pack/x-pack-5.6.5.zip",
      "extract": true,
      "executable": false,
      "cache": false
    }
  ],
  "healthChecks": [
    {
      "gracePeriodSeconds": 300,
      "intervalSeconds": 60,
      "maxConsecutiveFailures": 3,
      "port": 8080,
      "timeoutSeconds": 20,
      "delaySeconds": 15,
      "protocol": "MESOS_HTTP",
      "path": "/"
    }
  ],
  "instances": 1,
  "labels": {
    "DCOS_SERVICE_NAME": "kibana",
    "DCOS_PACKAGE_VERSION": "2.1.1-5.6.5",
    "DCOS_PACKAGE_NAME": "kibana"
  },
  "maxLaunchDelaySeconds": 3600,
  "mem": 2048,
  "gpus": 0,
  "networks": [
    {
      "name": "calico",
      "mode": "container",
      "labels": {
        "role": "kibana"
      }
    }
  ],
  "requirePorts": false,
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
  "constraints": []
}
```

```
dcos marathon app add /tmp/kibana.json
```

If deployed successfully. Kibana is reachable from the IP range configured within the Calico Policy. So could also be exposed via Marathon-LB or Edge-LB or accessed via SSH Tunnel:

```
ssh -L 8080:kibana.marathon.containerip.dcos.thisdcos.directory:8080 -A centos@<master-ip>
```
