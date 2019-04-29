## Expose Service via Marathon-LB

### Calico Policy

- Create Policy

First we need to define a Calico Policy in order for the Public Agent to be able to reach the Test Container. To discover the IP address assigned for the Calico Tunnel run something like the following on the Public Agents:

```
$ ip addr show tunl0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1
192.168.156.64
```

- Define this IP address within the Calico Policy for the Nginx Server and apply it via:

```yaml
calicoctl apply -f - <<EOF
apiVersion: v1
kind: policy
metadata:
  name: allow-nginx-ucr-tcp-80
spec:
  selector: role == 'nginx-ucr'
  ingress:
  - action: allow
    protocol: tcp
    source:
      nets:
        - "192.168.156.64/32"
    destination:
      ports:
      - 8080
  egress:
  - action: allow
EOF
```

### Deploy Container for Testing

- Allow Marathon to start containers as `root` for easy testing

```
# Create permission to start containers as root
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:task:user:root \
-d '{"description":"Allows Linux user root to execute tasks"}' \
-H 'Content-Type: application/json'
# Grant permissions to Marathon
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:task:user:root/users/dcos_marathon/create
```

- Start simple Nginx server

```json
{
  "id": "/nginx-ucr",
  "user": "nobody",
  "container": {
    "type": "MESOS",
    "docker": {
      "image": "sdelrio/docker-minimal-nginx"
    },
    "portMappings": [
      {
        "containerPort": 8080,
        "hostPort": 0,
        "protocol": "tcp",
        "name": "web"
      }
    ]
  },
  "cpus": 0.1,
  "healthChecks": [
    {
      "portIndex": 0,
      "protocol": "MESOS_HTTP",
      "path": "/"
    }
  ],
  "instances": 1,
  "mem": 128,
  "networks": [
    {
      "name": "calico",
      "mode": "container",
      "labels": {
        "role": "nginx-ucr"
      }
    }
  ],
  "labels": {
    "HAPROXY_GROUP": "external",
    "HAPROXY_0_VHOST": "<your-vhost>"
  },
  "portDefinitions": [
    {
      "protocol": "tcp",
      "port": 8080,
      "name": "nginx-ucr"
    }
  ]
}
```

### Install Marathon-LB

- Install Enterprise CLI

```
dcos package install dcos-enterprise-cli --cli --yes
```

- Setup service account for Marathon-LB

```
dcos security org service-accounts keypair /tmp/mlb-private-key.pem /tmp/mlb-public-key.pem
dcos security org service-accounts create -p /tmp/mlb-public-key.pem -d "Marathon-LB service account" mlb-principal
dcos security secrets create-sa-secret --strict /tmp/mlb-private-key.pem mlb-principal marathon-lb/mlb-secret
```

- Create and grant permissions

```
dcos security org users grant mlb-principal dcos:service:marathon:marathon:services:/ read --description "Allows access to any service launched by the native Marathon instance"
dcos security org users grant mlb-principal dcos:service:marathon:marathon:admin:events read --description "Allows access to Marathon events"
```

- Create configuration file

```
cat <<EOF > /tmp/mlb.json
{
    "marathon-lb": {
        "secret_name": "marathon-lb/mlb-secret",
        "marathon-uri": "https://marathon.mesos:8443"
    }
}
EOF
```

- Install Marathon-LB

```
dcos package install --options=/tmp/mlb.json marathon-lb
```
