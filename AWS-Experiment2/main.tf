provider "aws" {
  profile = "default"
  region  = var.region
}


# Create a new VPC
resource "aws_vpc" "exp2-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    "Name" = "exp2-VPC"
  }
}

# Create an internet gateway and attach it to our Terraformed VPC
resource "aws_internet_gateway" "exp2-internet-gateway" {
  vpc_id = aws_vpc.exp2-vpc.id
  tags = {
    "Name" = "exp2-Internet-Gateway"
  }
}

# Create a route table to send everything to the internet gateway
resource "aws_route_table" "exp2-route-table" {
  vpc_id = aws_vpc.exp2-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.exp2-internet-gateway.id
  }
}

# Create what will be our public subnets
resource "aws_subnet" "exp2-subnet-1a" {
  vpc_id            = aws_vpc.exp2-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ca-central-1a"
  tags = {
    "Name" = "exp2-Subnet-1a"
  }
}

resource "aws_subnet" "exp2-subnet-1b" {
  vpc_id            = aws_vpc.exp2-vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ca-central-1b"
  tags = {
    "Name" = "exp2-Subnet-1b"
  }
}


# Associate our public subnets with our route table
resource "aws_route_table_association" "exp2-subnet-1a-rta" {
  subnet_id      = aws_subnet.exp2-subnet-1a.id
  route_table_id = aws_route_table.exp2-route-table.id
}

resource "aws_route_table_association" "exp2-subnet-1b-rta" {
  subnet_id      = aws_subnet.exp2-subnet-1b.id
  route_table_id = aws_route_table.exp2-route-table.id
}



# Create a security group to allow incoming SSH from home
resource "aws_security_group" "exp2-sg-allow-ssh-from-home" {
  name        = "exp2-sg-allow-ssh-from-home"
  description = "Allow SSH from home IP"
  vpc_id      = aws_vpc.exp2-vpc.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["206.248.172.36/32"]
  }
  tags = {
    Name = "exp2-sg-allow-ssh-from-home"
  }
}


# Create a security group for the load balancer to allow incoming WWW from home and access to web server instances
resource "aws_security_group" "exp2-sg-load-balancer" {
  name        = "exp2-sg-load-balancer"
  description = "Security group tailored to the load balancers requirements"
  vpc_id      = aws_vpc.exp2-vpc.id
  tags = {
    Name = "exp2-sg-load-balancer"
  }
}

resource "aws_security_group_rule" "exp2-sgrule-load-balancer-allow-www" {
  type              = "ingress"
  description       = "Allow incoming WWW to the load balancer from everywhere"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.exp2-sg-load-balancer.id
}

resource "aws_security_group_rule" "exp2-sgrule-www-to-webservers" {
  type                     = "egress"
  description              = "Allow the load balancer to reach internal web servers"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.exp2-sg-webserver.id
  security_group_id        = aws_security_group.exp2-sg-load-balancer.id
}


# Create a security group for web server instances to allow incoming WWW from load balancer
resource "aws_security_group" "exp2-sg-webserver" {
  name        = "exp2-sg-webserver"
  description = "Security group tailored to the web servers requirements"
  vpc_id      = aws_vpc.exp2-vpc.id
  tags = {
    Name = "exp2-sg-webserver"
  }
}

resource "aws_security_group_rule" "exp2-sgrule-www-from-load-balancer" {
  type                     = "ingress"
  description              = "Allow the load balancer to reach internal web servers"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.exp2-sg-load-balancer.id
  security_group_id        = aws_security_group.exp2-sg-webserver.id
}


# Create a launch template for a bitnami nginx EC2 instance (our web server for this experiment)
resource "aws_launch_template" "exp2-launch-template-webserver" {
  name                   = "exp2-launch-template-webserver"
  update_default_version = true
  image_id               = "ami-0a09ff033117a19ea"
  instance_type          = "t2.nano"
  key_name               = "MyKeyPair"
  network_interfaces {
    associate_public_ip_address = true
    subnet_id                   = aws_subnet.exp2-subnet-1a.id
    security_groups             = [aws_security_group.exp2-sg-allow-ssh-from-home.id, aws_security_group.exp2-sg-webserver.id]
    device_index                = 0
  }
}

# Create a target group for the web server instances that will be associated with our auto-scaling group and load balancer
resource "aws_lb_target_group" "exp2-lb-target-group-webserver" {
  name     = "exp2-lb-target-group-webserver"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.exp2-vpc.id
}

# Create an auto-scaling group to manage instances based on our webserver launch template
resource "aws_autoscaling_group" "exp2-autoscaling-group-webserver" {
  name             = "exp2-autoscaling-group-webserver"
  desired_capacity = 2
  max_size         = 2
  min_size         = 2
  launch_template {
    id      = aws_launch_template.exp2-launch-template-webserver.id
    version = "$Latest"
  }
  target_group_arns = [aws_lb_target_group.exp2-lb-target-group-webserver.arn]
}


# Create a load balancer for the web server instances
resource "aws_lb" "exp2-lb-webserver" {
  name                       = "exp2-lb-webserver"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.exp2-sg-load-balancer.id]
  subnets                    = [aws_subnet.exp2-subnet-1a.id, aws_subnet.exp2-subnet-1b.id]
  enable_deletion_protection = false
}

# Add a listener to the load balancer that will forward incoming requests to our webserver target group
resource "aws_lb_listener" "exp2-lb-webserver-listener" {
  load_balancer_arn = aws_lb.exp2-lb-webserver.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.exp2-lb-target-group-webserver.arn
  }
}
