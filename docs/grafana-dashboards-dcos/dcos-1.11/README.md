# DC/OS 1.11 Metrics

## Setup Prometheus Mesos Exporter

[Documentation][mesos-exporter]

DC/OS 1.11 doesn't expose Mesos metrics out of the box. You need to aggregate them manually via a tool called Mesos Exporter. Download the Mesos Exporter binary to every Master node and copy it to the `/usr/bin`.

```bash
curl -L https://github.com/mesos/mesos_exporter/releases/download/v1.1.1/mesos_exporter-1.1.1.linux-amd64.tar.gz -o ./mesos_exporter.tar.gz
tar xvf ./mesos_exporter.tar.gz
cp ./mesos_exporter-*/mesos_exporter /usr/bin/
```

Setup a Systemd unit for the Mesos Exporter, to be automatically restarted in case of failures or system reboots.

```bash
cat <<EOF | sudo tee /etc/systemd/system/mesos-exporter.service
[Unit]
Description=DC/OS Mesos Exporter service
Wants=dcos.target
After=dcos.target

[Service]
Restart=always
RestartSec=5

ExecStart=/bin/sh -c '/usr/bin/mesos_exporter -enableMasterState -master http://$(/opt/mesosphere/bin/detect_ip):5050'

[Install]
WantedBy=multi-user.target
EOF
```

Enable the Systemd service.

```bash
systemctl daemon-reload
sudo systemctl enable mesos-exporter
sudo systemctl restart mesos-exporter
```

Your Prometheus instance needs to scrape the Mesos Exporter endpoints. You can find an example Job configuration below.

```yaml
  - job_name: 'mesos-exporter-master'

    dns_sd_configs:
      - names: ['master.mesos']
        type: 'A'
        port: 9105
```

[mesos-exporter]: https://github.com/mesos/mesos_exporter