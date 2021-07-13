output "load_balancer_dns" {
  description = "Public DNS of the load balancer"
  value       = aws_lb.exp2-lb-webserver.dns_name
}
