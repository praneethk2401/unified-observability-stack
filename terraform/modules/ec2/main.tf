# IAM Role for EC2
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-ec2-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Attach SSM policy
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach CloudWatch policy
resource "aws_iam_role_policy_attachment" "cloudwatch_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# Security Group for Prometheus
resource "aws_security_group" "prometheus" {
  name        = "${var.project_name}-${var.environment}-prometheus-sg"
  description = "Security group for Prometheus server"
  vpc_id      = var.vpc_id

  ingress {
    description = "Prometheus UI"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    description = "Node Exporter"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    description = "AlertManager"
    from_port   = 9093
    to_port     = 9093
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    description = "Loki"
    from_port   = 3100
    to_port     = 3100
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-prometheus-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Security Group for Grafana
resource "aws_security_group" "grafana" {
  name        = "${var.project_name}-${var.environment}-grafana-sg"
  description = "Security group for Grafana server"
  vpc_id      = var.vpc_id

  ingress {
    description = "Grafana UI"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-grafana-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Prometheus EC2 Instance
resource "aws_instance" "prometheus" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.prometheus.id]
  depends_on = [
    aws_security_group.prometheus,
    aws_iam_instance_profile.ec2_profile
  ]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y

    # Install Prometheus
    useradd --no-create-home --shell /bin/false prometheus
    mkdir /etc/prometheus /var/lib/prometheus

    cd /tmp
    wget https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.linux-amd64.tar.gz
    tar xvf prometheus-2.45.0.linux-amd64.tar.gz
    cp prometheus-2.45.0.linux-amd64/prometheus /usr/local/bin/
    cp prometheus-2.45.0.linux-amd64/promtool /usr/local/bin/
    cp -r prometheus-2.45.0.linux-amd64/consoles /etc/prometheus
    cp -r prometheus-2.45.0.linux-amd64/console_libraries /etc/prometheus

    # Prometheus config
    cat > /etc/prometheus/prometheus.yml << 'PROMEOF'
    global:
      scrape_interval: 15s

    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']

      - job_name: 'node'
        static_configs:
          - targets: ['localhost:9100']
    PROMEOF

    chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
    chown prometheus:prometheus /usr/local/bin/prometheus /usr/local/bin/promtool

    # Prometheus systemd service
    cat > /etc/systemd/system/prometheus.service << 'SVCEOF'
    [Unit]
    Description=Prometheus
    After=network.target

    [Service]
    User=prometheus
    ExecStart=/usr/local/bin/prometheus \
      --config.file=/etc/prometheus/prometheus.yml \
      --storage.tsdb.path=/var/lib/prometheus
    Restart=always

    [Install]
    WantedBy=multi-user.target
    SVCEOF

    # Install Node Exporter
    cd /tmp
    wget https://github.com/prometheus/node_exporter/releases/download/v1.6.0/node_exporter-1.6.0.linux-amd64.tar.gz
    tar xvf node_exporter-1.6.0.linux-amd64.tar.gz
    cp node_exporter-1.6.0.linux-amd64/node_exporter /usr/local/bin/
    useradd --no-create-home --shell /bin/false node_exporter

    cat > /etc/systemd/system/node_exporter.service << 'SVCEOF'
    [Unit]
    Description=Node Exporter
    After=network.target

    [Service]
    User=node_exporter
    ExecStart=/usr/local/bin/node_exporter
    Restart=always

    [Install]
    WantedBy=multi-user.target
    SVCEOF

    systemctl daemon-reload
    systemctl enable prometheus node_exporter
    systemctl start prometheus node_exporter
  EOF
  )

  tags = {
    Name        = "${var.project_name}-${var.environment}-prometheus"
    Environment = var.environment
    Project     = var.project_name
    Role        = "prometheus"
  }
}

# Grafana EC2 Instance
resource "aws_instance" "grafana" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.grafana.id]
  depends_on = [
    aws_security_group.grafana,
    aws_iam_instance_profile.ec2_profile
  ]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y

    # Install Grafana
    cat > /etc/yum.repos.d/grafana.repo << 'REPOEOF'
    [grafana]
    name=grafana
    baseurl=https://packages.grafana.com/oss/rpm
    repo_gpgcheck=1
    enabled=1
    gpgcheck=1
    gpgkey=https://packages.grafana.com/gpg.key
    sslverify=1
    sslcacert=/etc/pki/tls/certs/ca-bundle.crt
    REPOEOF

    yum install -y grafana

    systemctl daemon-reload
    systemctl enable grafana-server
    systemctl start grafana-server
  EOF
  )

  tags = {
    Name        = "${var.project_name}-${var.environment}-grafana"
    Environment = var.environment
    Project     = var.project_name
    Role        = "grafana"
  }
}