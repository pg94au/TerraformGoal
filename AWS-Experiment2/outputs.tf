output "load_balancer_dns" {
  description = "Public DNS of the load balancer"
  value       = aws_lb.tf-load-balancer.dns_name
}
