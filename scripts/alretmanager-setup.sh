#!/bin/bash
# Run this on the Prometheus EC2 instance via SSM

# Install AlertManager
cd /tmp
wget https://github.com/prometheus/alertmanager/releases/download/v0.26.0/alertmanager-0.26.0.linux-amd64.tar.gz
tar xvf alertmanager-0.26.0.linux-amd64.tar.gz
cp alertmanager-0.26.0.linux-amd64/alertmanager /usr/local/bin/
cp alertmanager-0.26.0.linux-amd64/amtool /usr/local/bin/

useradd --no-create-home --shell /bin/false alertmanager
mkdir /etc/alertmanager /var/lib/alertmanager

# AlertManager config
cat > /etc/alertmanager/alertmanager.yml << 'EOF'
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'default'

receivers:
  - name: 'default'
    webhook_configs:
      - url: 'http://localhost:5001/'
EOF

chown -R alertmanager:alertmanager /etc/alertmanager /var/lib/alertmanager
chown alertmanager:alertmanager /usr/local/bin/alertmanager /usr/local/bin/amtool

# AlertManager systemd service
cat > /etc/systemd/system/alertmanager.service << 'EOF'
[Unit]
Description=AlertManager
After=network.target

[Service]
User=alertmanager
ExecStart=/usr/local/bin/alertmanager \
  --config.file=/etc/alertmanager/alertmanager.yml \
  --storage.path=/var/lib/alertmanager
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Update Prometheus config to include rules and alertmanager
cat > /etc/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s

rule_files:
  - /etc/prometheus/rules.yml

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['localhost:9093']

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
EOF

# Copy rules file
cat > /etc/prometheus/rules.yml << 'RULESEOF'
groups:
  - name: ec2_alerts
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is above 80% for more than 2 minutes"

      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 80
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage detected"
          description: "Memory usage is above 80% for more than 2 minutes"

      - alert: HighDiskUsage
        expr: 100 - ((node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100) > 85
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High disk usage detected"
          description: "Disk usage is above 85% for more than 5 minutes"

      - alert: InstanceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Instance is down"
          description: "A monitored instance has been down for more than 1 minute"
RULESEOF

chown prometheus:prometheus /etc/prometheus/rules.yml

systemctl daemon-reload
systemctl enable alertmanager
systemctl start alertmanager
systemctl restart prometheus

echo "AlertManager setup complete!"
echo "AlertManager UI: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9093"