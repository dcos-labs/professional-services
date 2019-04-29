# Expose Service via Edge-LB

## Calico Policy

- Create Policy

First we need to define 2 Calico Policies in order for the Edge-LB to be able to reach the Test Container and vice versa.

- Define the Calico Policy for the Test Container and apply it via:

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
      selector: role == 'edgelb'
    destination:
      ports:
      - 80
  egress:
  - action: allow
EOF
```

- Define the Calico Policy for Edge-LB and apply it via:

```yaml
calicoctl apply -f - <<EOF
apiVersion: v1
kind: policy
metadata:
  name: allow-edgelb
spec:
  selector: role == 'edgelb'
  ingress:
    - action: allow
      destination: {}
      source:
        nets:
          - "172.16.0.0/16"
  egress:
  - action: allow
EOF
```

## Deploy Container for Testing

- Install Enterprise CLI

```shell
dcos package install dcos-enterprise-cli --cli --yes
```

- Allow Marathon to start containers as `root` for easy testing

```shell
dcos security org users grant dcos_marathon dcos:mesos:master:task:user:root create
```

- Start simple Nginx server

```json
cat <<EOF > /tmp/nginx-ucr.json
{
  "id": "/nginx-ucr",
  "user": "root",
  "container": {
    "type": "MESOS",
    "docker": {
      "image": "nginx"
    }
  },
  "cpus": 0.1,
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
  ]
}
EOF
```

```shell
dcos marathon app add /tmp/nginx-ucr.json
```

## Install Edge-LB

- Add package repositories for Edge-LB

```shell
dcos package repo add --index=0 edgelb-aws \
  https://<AWS S3 bucket>/stub-universe-edgelb.json
dcos package repo add --index=0 edgelb-pool-aws \
  https://<AWS S3 bucket>/stub-universe-edgelb-pool.json
```

- Setup service account for Edge-LB

```shell
dcos security org service-accounts keypair /tmp/edge-lb-private-key.pem /tmp/edge-lb-public-key.pem
dcos security org service-accounts create -p /tmp/edge-lb-public-key.pem -d "Edge-LB service account" edge-lb-principal
dcos security secrets create-sa-secret --strict /tmp/edge-lb-private-key.pem edge-lb-principal dcos-edgelb/edge-lb-secret
```

- Create and grant permissions

```shell
dcos security org users grant edge-lb-principal dcos:adminrouter:service:marathon full
dcos security org users grant edge-lb-principal dcos:adminrouter:package full
dcos security org users grant edge-lb-principal dcos:adminrouter:service:edgelb full
dcos security org users grant edge-lb-principal dcos:service:marathon:marathon:services:/dcos-edgelb full
dcos security org users grant edge-lb-principal dcos:mesos:master:endpoint:path:/api/v1 full
dcos security org users grant edge-lb-principal dcos:mesos:master:endpoint:path:/api/v1/scheduler full
dcos security org users grant edge-lb-principal dcos:mesos:master:framework:principal:edge-lb-principal full
dcos security org users grant edge-lb-principal dcos:mesos:master:framework:role full
dcos security org users grant edge-lb-principal dcos:mesos:master:reservation:principal:edge-lb-principal full
dcos security org users grant edge-lb-principal dcos:mesos:master:reservation:role full
dcos security org users grant edge-lb-principal dcos:mesos:master:volume:principal:edge-lb-principal full
dcos security org users grant edge-lb-principal dcos:mesos:master:volume:role full
dcos security org users grant edge-lb-principal dcos:mesos:master:task:user:root full
dcos security org users grant edge-lb-principal dcos:mesos:master:task:app_id full
```

- Create configuration file

```shell
cat <<EOF > /tmp/edge-lb.json
{
  "service": {
    "secretName": "dcos-edgelb/edge-lb-secret",
    "principal": "edge-lb-principal",
    "mesosProtocol": "https"
  }
}
EOF
```

- Install Edge-LB

```shell
dcos package install --options=/tmp/edge-lb.json edgelb --yes
```

## Create a pool

https://docs.mesosphere.com/services/edge-lb/1.0/pool-configuration/v2-examples/#virtual-networks

In this example we create a pool that will be launched on the virtual network called "calico" and define the network role "edgelb".

```json
cat <<EOF > /tmp/calico-lb.json
{
  "apiVersion": "V2",
  "name": "calico-lb",
  "count": 1,
  "virtualNetworks": [
    {
      "name": "calico",
      "labels": {
        "role": "edgelb"
      }
    }
  ],
  "haproxy": {
    "frontends": [{
      "bindPort": 80,
      "protocol": "HTTP",
      "linkBackend": {
        "defaultBackend": "nginx-ucr"
      }
    }],
    "backends": [{
      "name": "nginx-ucr",
      "protocol": "HTTP",
      "services": [{
        "marathon": {
          "serviceID": "/nginx-ucr"
        },
        "endpoint": {
          "port": 80
        }
      }]
    }]
  }
}
EOF
```

- Grant permissions for the pool

```shell
dcos security org users grant edge-lb-principal dcos:adminrouter:service:dcos-edgelb/pools/calico-lb full
```

- Deploy the pool

```shell
dcos edgelb create /tmp/calico-lb.json
```

- Test the connection

```shell
$ curl edgelb-pool-0-server.dcos-edgelbpoolscalico-lb.containerip.dcos.thisdcos.directory
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

## Edge-LB as an internal load balancer (VIP replacement)

Since the Edge-LB pool can be started inside of the Calico subnet, we can also use it for internal Layer 4 load balancing. In this we could use a pool as a recplacement of [VIPs](../vip) and still would be able to enforce policies using network labels. We can simply change the agent `"role"` to `"*"` from the example configuration above and the Edge-LB pool will get deployed on a private Agent.

https://docs.mesosphere.com/services/edge-lb/1.0/pool-configuration/v2-examples/#internal-east-west-load-balancing

- Create

```json
cat <<EOF > /tmp/calico-internal-lb.json
{
  "apiVersion": "V2",
  "name": "calico-internal-lb",
  "role": "*",
  "count": 1,
  "virtualNetworks": [
    {
      "name": "calico",
      "labels": {
        "role": "edgelb"
      }
    }
  ],
  "haproxy": {
    "stats": {
      "bindPort": 9090
    },
    "frontends": [{
      "bindPort": 80,
      "protocol": "HTTP",
      "linkBackend": {
        "defaultBackend": "nginx-ucr"
      }
    }],
    "backends": [{
      "name": "nginx-ucr",
      "protocol": "HTTP",
      "services": [{
        "marathon": {
          "serviceID": "/nginx-ucr"
        },
        "endpoint": {
          "port": 80
        }
      }]
    }]
  }
}
EOF
```

- Grant permissions for the pool

```shell
dcos security org users grant edge-lb-principal dcos:adminrouter:service:dcos-edgelb/pools/calico-internal-lb full
```

- Deploy the pool

```shell
dcos edgelb create /tmp/calico-internal-lb.json
```

- Test the connection

```shell
$ curl edgelb-pool-0-server.dcos-edgelbpoolscalico-internal-lb.containerip.dcos.thisdcos.directory
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```