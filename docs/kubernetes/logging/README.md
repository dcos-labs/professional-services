# Kubernetes - Log Aggregation with Elastic, FluentD and Kibana (EFK)

One popular centralized logging solution is the Elasticsearch, Fluentd, and Kibana (EFK) stack.

Elasticsearch is a real-time, distributed, and scalable search engine which allows for full-text and structured search, as well as analytics. Elasticsearch is commonly deployed alongside Kibana, a data visualization frontend and dashboard.

In this guide we'll use Fluentd to collect, transform, and ship log data from Kubernetes to the Elasticsearch backend. Fluentd is used to tail container log files, filter and transform the log data, and deliver it to the Elasticsearch cluster.

## Install DC/OS Packages: Elastic + Kibana

- Install the DC/OS Enterprise CLI

```bash
dcos package install dcos-enterprise-cli --cli --yes
```

- Setup a Service Account for Elastic

```bash
dcos security org service-accounts keypair /tmp/elastic-private-key.pem /tmp/elastic-public-key.pem
dcos security org service-accounts' create -p /tmp/elastic-public-key.pem -d "Elastic service account" elastic
dcos security secrets create-sa-secret --strict /tmp/elastic-private-key.pem elastic elastic/secret
```

- Grant permissions to the Service Account

```bash
dcos security org users grant elastic 'dcos:mesos:master:framework:role:elastic-role' create
dcos security org users grant elastic 'dcos:mesos:master:reservation:role:elastic-role' create
dcos security org users grant elastic 'dcos:mesos:master:volume:role:elastic-role' create
dcos security org users grant elastic 'dcos:mesos:master:task:user:nobody' create
dcos security org users grant elastic 'dcos:mesos:master:reservation:principal:elastic' delete
dcos security org users grant elastic 'dcos:mesos:master:volume:principal:elastic' delete
dcos security org users grant elastic 'dcos:secrets:default:/elastic/*' full
dcos security org users grant elastic 'dcos:secrets:list:default:/elastic' read
dcos security org users grant elastic 'dcos:adminrouter:ops:ca:rw' full
dcos security org users grant elastic 'dcos:adminrouter:ops:ca:ro' full
```

- Define the options that Elastic should get installed with. For this demo we will enable X-Pack and transport encryption. Additionally we'll configure a ingest node, that will receive the logs from Kubernetes.

```json
cat <<EOF | tee /tmp/elastic.json
{
    "service": {
        "service_account": "elastic",
        "service_account_secret": "elastic/secret",
        "security": {
            "transport_encryption": {
                "enabled": true
            }
        }
    },
    "elasticsearch": {
      "xpack_enabled": true
    },
    "ingest_nodes": {
      "count": 1
    }  
}
EOF
```

- Install Elastic

```bash
dcos package install elastic --package-version 2.5.0-6.3.2 --options /tmp/elastic.json
```

- Configure Kibana with and point it to the Coordinator node for Elastic

```json
cat <<EOF | tee /tmp/kibana.json
{
    "kibana": {
        "xpack_enabled": true,
        "elasticsearch_tls": true,
        "elasticsearch_url": "https://coordinator.elastic.l4lb.thisdcos.directory:9200"
    }
}
EOF
```

- Install Kibana

```bash
dcos package install kibana --package-version 2.5.0-6.3.2 --options /tmp/kibana.json
```

## Fluentd DaemonSet

Fluentd will run as a DaemonSet on the Kubernetes cluster that we want to monitor.

- Add a `ServiceAccount`, `ClusterRole` and `ClusterRoleBinding`

```yaml
cat <<EOF | tee /tmp/fluentd-auth.yml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: fluentd
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  name: fluentd
  namespace: kube-system
rules:
- apiGroups:
  - ""
  resources:
  - pods
  - namespaces
  verbs:
  - get
  - list
  - watch
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: fluentd
roleRef:
  kind: ClusterRole
  name: fluentd
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: fluentd
  namespace: kube-system
EOF
```

```bash
kubectl apply -f /tmp/fluentd-auth.yml
```

- Deploy the DaemonSet

```yaml
cat <<EOF | tee /tmp/fluentd-daemonset.yml
---
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: fluentd
  namespace: kube-system
  labels:
    k8s-app: fluentd-logging
    version: v1
    kubernetes.io/cluster-service: "true"
spec:
  template:
    metadata:
      labels:
        k8s-app: fluentd-logging
        version: v1
        kubernetes.io/cluster-service: "true"
    spec:
      serviceAccount: fluentd
      serviceAccountName: fluentd
      tolerations:
      - effect: NoSchedule
        operator: Exists
      - key: CriticalAddonsOnly
        operator: Exists
      - effect: NoExecute
        operator: Exists
      containers:
      - name: fluentd
        image: fluent/fluentd-kubernetes-daemonset:v1.3-debian-elasticsearch-1
        env:
          - name:  FLUENT_ELASTICSEARCH_HOST
            value: "ingest-0-node.elastic.autoip.dcos.thisdcos.directory"
          - name:  FLUENT_ELASTICSEARCH_PORT
            value: "1025"
          - name: FLUENT_ELASTICSEARCH_SCHEME
            value: "https"
          - name: FLUENT_ELASTICSEARCH_SSL_VERIFY
            value: "false"
          - name: FLUENT_ELASTICSEARCH_USER
            value: "elastic"
          - name: FLUENT_ELASTICSEARCH_PASSWORD
            value: "changeme"
          - name: FLUENT_UID
            value: "0"
          - name: FLUENTD_SYSTEMD_CONF
            value: "disable"
        resources:
          limits:
            memory: 400Mi
          requests:
            cpu: 100m
            memory: 400Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
      terminationGracePeriodSeconds: 30
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
EOF
```

```bash
kubectl apply -f /tmp/fluentd-daemonset.yml
```

- Verify the DeamonSet is running

```bash
$ kubectl get ds -n kube-system
NAME          DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
calico-node   4         4         4       4            4           <none>          22h
fluentd       4         4         4       4            4           <none>          19s
```

## Setup Index in Kibana

Open Kibana at: `https://<dcos-master>/service/kibana`
Click on**Discover**in the left-hand navigation menu.
Enter `logstash-*` in the text box and click on **Next step**.
This allows you to configure which field Kibana will use to filter log data by time. In the dropdown, select the `@timestamp` field, and hit **Create index pattern**.
Now, hit **Discover** in the left hand navigation menu.

## Testing

This is a minimal Pod called **counter** that runs a `while` loop, printing numbers sequentially.

```yaml
cat <<EOF | tee /tmp/counter.yml
apiVersion: v1
kind: Pod
metadata:
  name: counter
spec:
  containers:
  - name: count
    image: busybox
    args: [/bin/sh, -c,
            'i=0; while true; do echo "$i: $(date)"; i=$((i+1)); sleep 1; done']
EOF
```

```bash
kubectl apply -f /tmp/counter.yml
```

From the **Discover** page, in the search bar enter `kubernetes.pod_name:counter`.  This filters the log data for Pods named `counter`.

Ref.:

- [fluent/fluentd-kubernetes-daemonset · GitHub](https://github.com/fluent/fluentd-kubernetes-daemonset/blob/master/fluentd-daemonset-elasticsearch-rbac.yaml)
- [Kubernetes Logging with Fluentd | Fluentd](https://docs.fluentd.org/v0.12/articles/kubernetes-fluentd)
- [How To Set Up EFK | DigitalOcean](https://www.digitalocean.com/community/tutorials/how-to-set-up-an-elasticsearch-fluentd-and-kibana-efk-logging-stack-on-kubernetes#step-1-%E2%80%94-creating-a-namespace)
