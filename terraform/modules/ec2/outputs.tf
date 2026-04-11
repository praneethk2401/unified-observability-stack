output "prometheus_public_ip" {
  description = "Public IP of Prometheus server"
  value       = aws_instance.prometheus.public_ip
}

output "grafana_public_ip" {
  description = "Public IP of Grafana server"
  value       = aws_instance.grafana.public_ip
}

output "prometheus_instance_id" {
  description = "Instance ID of Prometheus server"
  value       = aws_instance.prometheus.id
}

output "grafana_instance_id" {
  description = "Instance ID of Grafana server"
  value       = aws_instance.grafana.id
}