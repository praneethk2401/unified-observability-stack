output "prometheus_url" {
  description = "Prometheus UI URL"
  value       = "http://${module.ec2.prometheus_public_ip}:9090"
}

output "grafana_url" {
  description = "Grafana UI URL"
  value       = "http://${module.ec2.grafana_public_ip}:3000"
}

output "prometheus_public_ip" {
  description = "Prometheus server public IP"
  value       = module.ec2.prometheus_public_ip
}

output "grafana_public_ip" {
  description = "Grafana server public IP"
  value       = module.ec2.grafana_public_ip
}