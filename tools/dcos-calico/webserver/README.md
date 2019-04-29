# Configure a Simple Webserver

## Deploy Containers for Testing

- Install Enterprise CLI

```shell
dcos package install dcos-enterprise-cli --cli --yes
```

- Allow Marathon to start containers as `root` for easy testing

```shell
dcos security org users grant dcos_marathon dcos:mesos:master:task:user:root create
```

- Start Nginx server

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

- Start a container `test-allow` that should be allowed to curl the Nginx server below

```json
cat <<EOF > /tmp/test-allow.json
{
  "id": "/test-allow",
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
        "role": "test-allow"
      }
    }
  ]
}
EOF
```

```shell
dcos marathon app add /tmp/test-allow.json
```

- Start a second container `test-deny` that should NOT be allowed to curl the Nginx server

```json
cat <<EOF > /tmp/test-deny.json
{
  "id": "/test-deny",
  "user": "root",
  "cmd": "while true; do echo 'Access to Nginx: Denied'; sleep 60; done",
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
        "role": "test-deny"
      }
    }
  ]
}
EOF
```

```shell
dcos marathon app add /tmp/test-deny.json
```

## Calico policy

- Setup profile for `nginx-ucr` to be only accessible from `/test-allow`.

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
      selector: role == 'test-allow'
    destination:
      ports:
      - 80
  egress:
  - action: allow
EOF
```

## Test the connection

- We jump into the container `test-allow` and try to curl the Nginx Server. This should work fine:

```shell
$ dcos task exec test-allow curl nginx-ucr.marathon.containerip.dcos.thisdcos.directory
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

- If we jump into the second container `test-deny` and try to do the same. We should not be able to etablish an connection:

```shell
$ dcos task exec test-deny curl nginx-ucr.marathon.containerip.dcos.thisdcos.directory
Overwriting environment variable 'LIBPROCESS_IP'
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:--  0:00:13 --:--:--     0
```