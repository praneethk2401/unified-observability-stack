#!/bin/bash
# Run this on the Prometheus EC2 instance via SSM

# Install Python dependencies
yum install -y python3 python3-pip

# Install OpenTelemetry Collector
cd /tmp
wget https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.88.0/otelcol_0.88.0_linux_amd64.tar.gz
tar xvf otelcol_0.88.0_linux_amd64.tar.gz
cp otelcol /usr/local/bin/
chmod +x /usr/local/bin/otelcol

mkdir -p /etc/otelcol

# OpenTelemetry Collector config
cat > /etc/otelcol/config.yml << 'EOF'
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:

exporters:
  logging:
    loglevel: debug
  prometheus:
    endpoint: "0.0.0.0:8889"

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [logging]
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [prometheus]
EOF

# OTel Collector systemd service
cat > /etc/systemd/system/otelcol.service << 'EOF'
[Unit]
Description=OpenTelemetry Collector
After=network.target

[Service]
ExecStart=/usr/local/bin/otelcol --config=/etc/otelcol/config.yml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Install and run the Flask app
mkdir -p /opt/demo-app
cat > /opt/demo-app/requirements.txt << 'REQEOF'
flask==2.3.0
opentelemetry-api==1.20.0
opentelemetry-sdk==1.20.0
opentelemetry-instrumentation-flask==0.41b0
opentelemetry-exporter-otlp==1.20.0
boto3==1.26.0
requests==2.31.0
REQEOF

pip3 install -r /opt/demo-app/requirements.txt

cat > /opt/demo-app/app.py << 'APPEOF'
import boto3
import json
import random
import time
from flask import Flask, jsonify
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.resources import Resource
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor

resource = Resource.create({"service.name": "observability-demo-app"})
provider = TracerProvider(resource=resource)
otlp_exporter = OTLPSpanExporter(endpoint="http://localhost:4317", insecure=True)
provider.add_span_processor(BatchSpanProcessor(otlp_exporter))
trace.set_tracer_provider(provider)
tracer = trace.get_tracer(__name__)

app = Flask(__name__)
FlaskInstrumentor().instrument_app(app)

@app.route('/health')
def health():
    return jsonify({"status": "healthy"})

@app.route('/metrics-summary')
def metrics_summary():
    with tracer.start_as_current_span("fetch-metrics-summary") as span:
        time.sleep(random.uniform(0.1, 0.3))
        span.set_attribute("environment", "monitoring")
        with tracer.start_as_current_span("process-cpu-metrics"):
            time.sleep(random.uniform(0.05, 0.15))
            cpu_usage = random.uniform(10, 90)
        with tracer.start_as_current_span("process-memory-metrics"):
            time.sleep(random.uniform(0.05, 0.1))
            memory_usage = random.uniform(20, 80)
        return jsonify({"cpu_usage": round(cpu_usage, 2), "memory_usage": round(memory_usage, 2)})

@app.route('/simulate-slow')
def simulate_slow():
    with tracer.start_as_current_span("slow-operation") as span:
        delay = random.uniform(1, 3)
        span.set_attribute("db.query.duration", delay)
        time.sleep(delay)
        return jsonify({"duration_seconds": round(delay, 2)})

@app.route('/simulate-error')
def simulate_error():
    with tracer.start_as_current_span("error-operation") as span:
        try:
            if random.random() < 0.7:
                raise Exception("Simulated error!")
            return jsonify({"message": "Success"})
        except Exception as e:
            span.record_exception(e)
            span.set_status(trace.StatusCode.ERROR, str(e))
            return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
APPEOF

# Flask app systemd service
cat > /etc/systemd/system/demo-app.service << 'EOF'
[Unit]
Description=Demo Flask App
After=network.target otelcol.service

[Service]
ExecStart=/usr/bin/python3 /opt/demo-app/app.py
Restart=always
WorkingDirectory=/opt/demo-app

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable otelcol demo-app
systemctl start otelcol demo-app

echo "OpenTelemetry setup complete!"
systemctl status otelcol --no-pager
systemctl status demo-app --no-pager