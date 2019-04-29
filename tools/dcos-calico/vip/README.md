# Configure Named VIP

## Calico Policy

- Setup a Calico policy called `nginx-vip` to allow access from the Calico Subnet. This is needed in order for the VIP functionality to work properly.

```yaml
calicoctl apply -f - <<EOF
apiVersion: v1
kind: policy
metadata:
  name: allow-nginx-vip-tcp-80
spec:
  selector: role == 'nginx-vip'
  ingress:
  - action: allow
    protocol: tcp
    source:
      nets:
        - "172.16.0.0/16"
    destination:
      ports:
      - 80
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

- Start simple Nginx server and assign a VIP endpoint

```json
cat <<EOF > /tmp/nginx-vip.json
{
  "id": "/nginx-vip",
  "user": "root",
  "container": {
    "portMappings": [
      {
        "containerPort": 80,
        "labels": {
          "VIP_0": "/nginx-vip:80"
        },
        "servicePort": 0,
        "name": "default"
      }
    ],
    "type": "MESOS",
    "docker": {
      "image": "nginx"
    }
  },
  "cpus": 0.1,
  "instances": 3,
  "mem": 128,
  "networks": [
    {
      "name": "calico",
      "mode": "container",
      "labels": {
        "role": "nginx-vip"
      }
    }
  ]
}
EOF
```

```shell
dcos marathon app add /tmp/nginx-vip.json
```

- Start a container `test-vip` that will be used to curl the Nginx server

```json
cat <<EOF > /tmp/test-vip.json
{
  "id": "/test-vip",
  "user": "root",
  "cmd": "while true; do echo 'Access to Nginx: Allowed'; sleep 60; done",
  "container": {
    "type": "MESOS",
    "docker": {
      "image": "centos"
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
        "role": "test-vip"
      }
    }
  ]
}
EOF
```

```shell
dcos marathon app add /tmp/test-vip.json
```

## Test the connection

- We jump into the container `test-vip` and try to curl the Nginx Server via the VIP endpoint. This would be the expected output:

```shell
$ dcos task exec test-vip curl nginx-vip.marathon.l4lb.thisdcos.directory
Overwriting environment variable 'LIBPROCESS_IP'
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   612  100   612    0     0   122k      0 --:--:-- --:--:-- --:--:--  149k
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
