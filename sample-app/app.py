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

# Configure OpenTelemetry
resource = Resource.create({"service.name": "observability-demo-app"})
provider = TracerProvider(resource=resource)

# Export to OTLP collector (local)
otlp_exporter = OTLPSpanExporter(endpoint="http://localhost:4317", insecure=True)
provider.add_span_processor(BatchSpanProcessor(otlp_exporter))
trace.set_tracer_provider(provider)

tracer = trace.get_tracer(__name__)

app = Flask(__name__)
FlaskInstrumentor().instrument_app(app)

@app.route('/health')
def health():
    return jsonify({"status": "healthy", "service": "observability-demo"})

@app.route('/metrics-summary')
def metrics_summary():
    with tracer.start_as_current_span("fetch-metrics-summary") as span:
        # Simulate fetching metrics
        time.sleep(random.uniform(0.1, 0.3))

        span.set_attribute("metrics.count", 42)
        span.set_attribute("environment", "monitoring")

        with tracer.start_as_current_span("process-cpu-metrics"):
            time.sleep(random.uniform(0.05, 0.15))
            cpu_usage = random.uniform(10, 90)

        with tracer.start_as_current_span("process-memory-metrics"):
            time.sleep(random.uniform(0.05, 0.1))
            memory_usage = random.uniform(20, 80)

        return jsonify({
            "cpu_usage": round(cpu_usage, 2),
            "memory_usage": round(memory_usage, 2),
            "status": "ok"
        })

@app.route('/simulate-slow')
def simulate_slow():
    with tracer.start_as_current_span("slow-operation") as span:
        # Simulate a slow database query
        delay = random.uniform(1, 3)
        span.set_attribute("db.query.duration", delay)
        span.set_attribute("db.type", "simulated")
        time.sleep(delay)

        return jsonify({
            "message": "Slow operation completed",
            "duration_seconds": round(delay, 2)
        })

@app.route('/simulate-error')
def simulate_error():
    with tracer.start_as_current_span("error-operation") as span:
        try:
            # Simulate random errors
            if random.random() < 0.7:
                raise Exception("Simulated application error!")
            return jsonify({"message": "Success"})
        except Exception as e:
            span.record_exception(e)
            span.set_status(trace.StatusCode.ERROR, str(e))
            return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)