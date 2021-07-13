provider "aws" {
  profile = "default"
  region  = var.region
}

# Create a VPC named "Terraformed"
resource "aws_vpc" "tf-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    "Name" = "TF_VPC"
  }
}

# Create an internet gateway and attach it to our Terraformed VPC
resource "aws_internet_gateway" "tf-ig" {
  vpc_id = aws_vpc.tf-vpc.id
  tags = {
    "Name" = "TF_IG"
  }
}

# Create a route table to send everything to the internet gateway
resource "aws_route_table" "tf-rt" {
  vpc_id = aws_vpc.tf-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tf-ig.id
  }
}

# Create what will be our public subnets
resource "aws_subnet" "tf-public-subnet-1a" {
  vpc_id            = aws_vpc.tf-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ca-central-1a"
  tags = {
    "Name" = "TF_Public1a"
  }
}

resource "aws_subnet" "tf-public-subnet-1b" {
  vpc_id            = aws_vpc.tf-vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ca-central-1b"
  tags = {
    "Name" = "TF_Public1b"
  }
}


# Associate our public subnets with our route table
resource "aws_route_table_association" "tf-public-subnet-1a-rta" {
  subnet_id      = aws_subnet.tf-public-subnet-1a.id
  route_table_id = aws_route_table.tf-rt.id
}

resource "aws_route_table_association" "tf-public-subnet-1b-rta" {
  subnet_id      = aws_subnet.tf-public-subnet-1b.id
  route_table_id = aws_route_table.tf-rt.id
}


# Create a security group to allow incoming SSH from home
resource "aws_security_group" "tf-allow-ssh-from-home" {
  name        = "tf-allow-ssh-from-home"
  description = "Allow SSH from home IP"
  vpc_id      = aws_vpc.tf-vpc.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["206.248.172.36/32"]
  }
  tags = {
    Name = "tf-allow-ssh-from-home"
  }
}

# Create a security group for the load balancer to allow incoming WWW from home and access to web server instances
resource "aws_security_group" "tf-security-group-loadbalancer" {
  name        = "tf-security-group-loadbalancer"
  description = "Allow WWW from home IP"
  vpc_id      = aws_vpc.tf-vpc.id
  tags = {
    Name = "tf-security-group-loadbalancer"
  }
}

resource "aws_security_group_rule" "tf-security-group-rule-allow-www-from-home" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["206.248.172.36/32"]
  security_group_id = aws_security_group.tf-security-group-loadbalancer.id
}

resource "aws_security_group_rule" "tf-security-group-rule-allow-www-to-webserver" {
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.tf-security-group-webserver.id
  security_group_id        = aws_security_group.tf-security-group-loadbalancer.id
}

# Create a security group for web server instances to allow incoming WWW from load balancer
resource "aws_security_group" "tf-security-group-webserver" {
  name        = "tf-security-group-webserver"
  description = "Allow WWW from load balancer"
  vpc_id      = aws_vpc.tf-vpc.id
  tags = {
    Name = "tf-security-group-webserver"
  }
}

resource "aws_security_group_rule" "tf-security-group-rule-allow-www-from-loadbalancer" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.tf-security-group-loadbalancer.id
  security_group_id        = aws_security_group.tf-security-group-webserver.id
}


# Store a sample parameter in Parameter Store
resource "aws_ssm_parameter" "tf-paramter-foo" {
  name  = "foo"
  type  = "String"
  value = "bar"
}

# Create a launch template for a bitnami nginx EC2 instance
resource "aws_launch_template" "tf-launch-template" {
  name                   = "tf-launch-template"
  update_default_version = true
  image_id               = "ami-0a09ff033117a19ea"
  instance_type          = "t2.nano"
  key_name               = "MyKeyPair"
  network_interfaces {
    associate_public_ip_address = true
    subnet_id                   = aws_subnet.tf-public-subnet-1a.id
    security_groups             = [aws_security_group.tf-allow-ssh-from-home.id, aws_security_group.tf-security-group-webserver.id]
    device_index                = 0
  }
}

# Create an auto-scaling group to manage instances based on our bitnami nginx launch template
resource "aws_autoscaling_group" "tf-autoscaling-group" {
  name             = "tf-autoscaling-group"
  desired_capacity = 2
  max_size         = 2
  min_size         = 2
  launch_template {
    id      = aws_launch_template.tf-launch-template.id
    version = "$Latest"
  }
  target_group_arns = [aws_lb_target_group.tf-lb-target-group.arn]
}

# Create a target group for the web server instances that will be associated with our load balancer
resource "aws_lb_target_group" "tf-lb-target-group" {
  name     = "tf-lb-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.tf-vpc.id
}

# Create a load balancer for teh web server instances
resource "aws_lb" "tf-load-balancer" {
  name                       = "tf-load-balancer"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.tf-security-group-loadbalancer.id]
  subnets                    = [aws_subnet.tf-public-subnet-1a.id, aws_subnet.tf-public-subnet-1b.id]
  enable_deletion_protection = false
}

# Add a listener to the load balancer that will forward incoming requests to our target group
resource "aws_lb_listener" "tf-load-balancer-listener" {
  load_balancer_arn = aws_lb.tf-load-balancer.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tf-lb-target-group.arn
  }
}
