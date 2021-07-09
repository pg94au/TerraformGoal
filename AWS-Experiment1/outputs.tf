output "vpc_id" {
  description = "ID of the Terraformed VPC"
  value       = aws_vpc.tf-vpc.id
}

# output "instance_id" {
#   description = "ID of the instance"
#   value       = aws_instance.tf-instance.id
# }

# output "instance_public_ip" {
#   description = "Public IP address of the instance"
#   value       = aws_instance.tf-instance.public_ip
# }
