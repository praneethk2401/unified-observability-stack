markdown# Unified Observability Stack

A production-grade observability platform built on AWS using Terraform,
demonstrating the three pillars of observability — metrics, logs, and
traces — with automated alerting and operational runbooks.

## Architecture Overview

┌─────────────────────────────────────────────────────────────┐
│                    AWS Account (ap-south-2)                 │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                 Monitoring VPC (10.0.0.0/16)        │    │
│  │                                                     │    │
│  │  ┌─────────────────────┐  ┌─────────────────────┐   │    │
│  │  │   Prometheus EC2    │  │    Grafana EC2      │   │    │
│  │  │                     │  │                     │   │    │
│  │  │  • Prometheus :9090 │  │  • Grafana    :3000 │   │    │
│  │  │  • Node Exporter    │  │                     │   │    │
│  │  │  • AlertManager     │  │                     │   │    │
│  │  │  • Loki       :3100 │  │                     │   │    │
│  │  │  • Promtail         │  │                     │   │    │
│  │  │  • Tempo      :3200 │  │                     │   │    │
│  │  │  • Flask App  :5000 │  │                     │   │    │
│  │  └─────────────────────┘  └─────────────────────┘   │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
Metrics  → Prometheus + Node Exporter → Grafana
Logs     → Promtail → Loki → Grafana
Traces   → Flask App + OpenTelemetry → Tempo → Grafana
Alerts   → Prometheus Rules → AlertManager → SNS

## Three Pillars of Observability

### Metrics — Prometheus + Grafana
- Node Exporter scrapes EC2 system metrics every 15 seconds
- CPU, memory, disk, and network usage tracked in real time
- Grafana dashboards with live time series visualisations
- AlertManager fires alerts when thresholds are breached

### Logs — Loki + Promtail
- Promtail agent ships system logs automatically to Loki
- Logs queryable in Grafana alongside metrics
- Single pane of glass for metrics and logs together

### Traces — OpenTelemetry + Tempo
- Python Flask demo app instrumented with OpenTelemetry SDK
- Distributed traces shipped to Grafana Tempo via OTLP
- Trace waterfall view shows exactly how long each span takes
- Simulated slow requests and errors for realistic testing

## Alerting

|      Alert      | Severity |           Threshold             |
|-----------------|----------|---------------------------------|
| HighCPUUsage    | Warning  | CPU > 80% for 2 minutes         |
| HighMemoryUsage | Warning  | Memory > 80% for 2 minutes      |
| InstanceDown    | Critical | Target unreachable for 1 minute |

Alert chain:
Prometheus detects threshold breach
↓
Alert moves INACTIVE → PENDING → FIRING
↓
AlertManager receives firing alert
↓
Notification sent to SNS

## Runbooks

Operational runbooks for every alert type:

- [High CPU Usage](runbooks/high-cpu-usage.md)
- [High Memory Usage](runbooks/high-memory-usage.md)
- [Instance Down](runbooks/instance-down.md)

## Tech Stack

| Category | Technology                        |
|-------------|--------------------------------|
| Cloud       | AWS                            |
| IaC         | Terraform                      |
| Metrics     | Prometheus, Node Exporter      |
| Logs        | Grafana Loki, Promtail         |
| Traces      | OpenTelemetry, Grafana Tempo   |
| Dashboards  | Grafana                        |
| Alerting    | AlertManager, Prometheus Rules |
| Application | Python, Flask                  |
| CI/CD       | GitHub Actions                 |

## Project Structure

unified-observability-stack/
├── .github/
│   └── workflows/
│       └── terraform-validate.yml  # CI/CD pipeline
├── terraform/
│   ├── modules/
│   │   ├── vpc/                    # VPC, subnet, IGW
│   │   └── ec2/                    # EC2, IAM, security groups
│   └── environments/
│       └── monitoring/             # Monitoring environment
├── sample-app/
│   ├── app.py                      # Flask app with OTel tracing
│   ├── requirements.txt
│   └── setup.sh                    # Installation script
├── scripts/
│   ├── alertmanager-setup.sh       # AlertManager installation
│   └── prometheus-rules.yml        # Alert rules
├── runbooks/
│   ├── high-cpu-usage.md           # CPU alert runbook
│   ├── high-memory-usage.md        # Memory alert runbook
│   └── instance-down.md            # Instance down runbook
├── docs/
│   └── known-issues.md             # Known issues and workarounds
├── diagrams/
│   └── screenshots/                # AWS Console evidence
└── README.md

## Known Issues

### Terraform Destroy — VPC Dependency Error
Occasionally terraform destroy fails with a VPC dependency error.

Manual cleanup order:
1. AWS Console → VPC → Endpoints → Delete all
2. AWS Console → EC2 → Network Interfaces → Delete all
3. AWS Console → VPC → Subnets → Delete subnet
4. AWS Console → VPC → Your VPCs → Delete the VPC
4. Run `terraform destroy` again

### Terraform Destroy — Network Connectivity Error
If destroy fails with `no such host` — internet connection dropped.
Simply run `terraform destroy` again — Terraform resumes from
where it left off.

### SSM Session Manager — Script Execution
Scripts must be pasted directly into SSM session as the script
files live on the local machine, not the EC2 instance. For
production, scripts should be baked into EC2 user data in
Terraform so everything installs automatically on boot.

## Author

**Praneeth Kulkarni**