# DC/OS 1.12 Metrics

## Enable Mesos Metics via Telegraf

[Documentation][mesosphere-metrics-mesos]

DC/OS 1.12 doesn't expose Mesos metrics out of the box. You need to enable them in Telegraf.

On every master node in your cluster, do the following tasks:

```bash
cat <<EOF | sudo tee /var/lib/dcos/telegraf/telegraf.d/mesos-master.conf
# Gathers all Mesos metrics
[[inputs.mesos]]
  # The interval at which to collect metrics
  interval = "60s"
  # Timeout, in ms.
  timeout = 30000
  # A list of Mesos masters.
  masters = ["http://\$DCOS_NODE_PRIVATE_IP:5050"]
EOF
```

```bash
sudo systemctl restart dcos-telegraf
```

On every agent node in your cluster, do the following tasks:

```bash
cat <<EOF | sudo tee /var/lib/dcos/telegraf/telegraf.d/mesos-agent.conf
# Gathers all Mesos metrics
[[inputs.mesos]]
  # The interval at which to collect metrics
  interval = "60s"
  # Timeout, in ms.
  timeout = 30000
  # A list of Mesos slaves.
  slaves = ["http://\$DCOS_NODE_PRIVATE_IP:5051"]
EOF
```

```bash
sudo systemctl restart dcos-telegraf
```

[mesosphere-metrics-mesos]: https://docs.mesosphere.com/1.12/metrics/mesos/