## Calico policies

To keep the rule design simple and powerful, each application should get its own profile and respective role named after the application. Afterwards a whitelist approach can be configured, so that each profile contains rules to explicitly allow a specific role access. Further restrictions inside the cluster network and the internet should be configured using CIDR notation.

### Expose Marathon Service via AdminRouter

- Allow Marathon to start containers as `root` for easy testing

```bash
# Create permission to start containers as root
dcos security org users grant dcos_marathon dcos:mesos:master:task:user:root create
```

- Start simple Nginx Service

```json
cat <<EOF > /tmp/nginx-service.json
{
  "id": "/nginx-service",
  "container": {
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 0,
        "protocol": "tcp",
        "servicePort": 0,
        "name": "default"
      }
    ],
    "type": "MESOS",
    "docker": {
      "image": "nginx",
      "forcePullImage": false,
      "parameters": [],
      "privileged": false
    }
  },
  "cpus": 0.1,
  "instances": 1,
  "mem": 128,
  "networks": [
    {
      "mode": "container",
      "name": "calico",
      "labels": {
        "role": "nginx-service"
      }
    }
  ],
  "user": "root",
  "killSelection": "YOUNGEST_FIRST",
  "labels": {
    "DCOS_SERVICE_SCHEME": "http",
    "DCOS_SERVICE_NAME": "nginx-service",
    "DCOS_SERVICE_PORT_INDEX": "0"
  }
}
EOF
```

```bash
dcos marathon app add /tmp/nginx-service.json
```

- Setup profile for `nginx-service` to be accessible from the Masters

```yaml
calicoctl apply -f - <<EOF
apiVersion: v1
kind: policy
metadata:
  name: allow-nginx-service-tcp
spec:
  selector: role == 'nginx-service'
  ingress:
  - action: allow
    protocol: tcp
    source:
      nets:
        - "172.16.0.0/16"
  egress:
  - action: allow
EOF
```