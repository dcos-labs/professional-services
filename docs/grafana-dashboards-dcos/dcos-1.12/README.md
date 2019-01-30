# DC/OS 1.12 Metrics

## Enable Mesos Metrics via Telegraf

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

## Enable Edge-LB (HAProxy) Metrics via Telegraf

[Documentation][telegraf-prometheus]

HAProxy doesn't expose Metrics via the Prometheus format. You need to aggregate them via a tool called HAProxy Exporter.

Download the HAProxy Exporter binary to every Public Agent node and copy it to the `/usr/bin` directory.

```bash
curl -L 'https://github.com/prometheus/haproxy_exporter/releases/download/v0.10.0/haproxy_exporter-0.10.0.linux-amd64.tar.gz' -o ./haproxy_exporter.tar.gz
tar xvf ./haproxy_exporter.tar.gz
sudo cp ./haproxy_exporter-*/haproxy_exporter /usr/bin/
```

Setup a `systemd` unit for the HAProxy Exporter, in order that it will be automatically restarted in case of failures or system reboots.

```bash
cat <<EOF | sudo tee /etc/systemd/system/haproxy-exporter.service
[Unit]
Description=Edge-LB/HAProxy Exporter service
Wants=dcos.target
After=dcos.target

[Service]
Restart=always
RestartSec=5

ExecStart=/bin/sh -c '/usr/bin/haproxy_exporter --haproxy.scrape-uri="http://$(/opt/mesosphere/bin/detect_ip):9090/haproxy?stats;csv"'

[Install]
WantedBy=multi-user.target
EOF
```

Enable and start the systemd service.

```bash
sudo systemctl daemon-reload
sudo systemctl enable haproxy-exporter
sudo systemctl restart haproxy-exporter
```

Configure Telegraf on every Public Agent node to scrape the metrics from the HAProxy Exporter.

```bash
cat <<EOF | sudo tee /var/lib/dcos/telegraf/telegraf.d/haproxy-exporter.conf
# Read metrics prometheus haproxy exporter
[[inputs.prometheus]]
  ## An array of urls to scrape metrics from.
  urls = ["http://\$DCOS_NODE_PRIVATE_IP:9101/metrics"]
EOF
```

Restart Telegraf to apply the configuration:

```bash
sudo systemctl restart dcos-telegraf
```

[mesosphere-metrics-mesos]: https://docs.mesosphere.com/1.12/metrics/mesos/
[telegraf-prometheus]: https://github.com/influxdata/telegraf/tree/master/plugins/inputs/prometheus