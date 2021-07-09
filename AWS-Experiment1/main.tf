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

# Create what will be our public subnet
resource "aws_subnet" "tf-public-subnet-1a" {
  vpc_id            = aws_vpc.tf-vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ca-central-1a"
  tags = {
    "Name" = "TF_Public1a"
  }
}

# Associate our public subnet with our route table
resource "aws_route_table_association" "tf-public-subnet-1a-rta" {
  subnet_id      = aws_subnet.tf-public-subnet-1a.id
  route_table_id = aws_route_table.tf-rt.id
}

# Create a security group to allow incoming SSH from home
resource "aws_security_group" "tf-allow-ssh-from-home" {
  name        = "tf-allow-ssh-from-home"
  description = "Allow SSH from home IP"
  vpc_id      = aws_vpc.tf-vpc.id
  ingress {
    from_port   = 0
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["206.248.172.36/32"]
  }
  ingress {
    from_port   = 0
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["206.248.172.36/32"]
  }
  tags = {
    Name = "tf-allow-ssh-from-home"
  }
}

# Store a sample parameter in Parameter Store
resource "aws_ssm_parameter" "tf-paramter-foo" {
  name  = "foo"
  type  = "String"
  value = "bar"
}

# Create a launch template for a bitnami nginx EC2 instance
resource "aws_launch_template" "tf-launch-template" {
  name                        = "tf-launch-template"
  update_default_version      = true
  image_id                    = "ami-0a09ff033117a19ea"
  instance_type               = "t2.nano"
  key_name                    = "MyKeyPair"
  network_interfaces {
    associate_public_ip_address = true
    subnet_id                   = aws_subnet.tf-public-subnet-1a.id
    security_groups             = [aws_security_group.tf-allow-ssh-from-home.id] 
  }
#  vpc_security_group_ids      = [aws_security_group.tf-allow-ssh-from-home.id]
}

# A bitnami nginx instance based on Debian (login username "bitnami")
# resource "aws_instance" "tf-instance" {
# #  ami                         = "ami-0801628222e2e96d6"
#   ami                         = "ami-0a09ff033117a19ea"
#   instance_type               = "t2.nano"
#   subnet_id                   = aws_subnet.tf-public-subnet-1a.id
#   associate_public_ip_address = true
#   key_name                    = "MyKeyPair"
#   vpc_security_group_ids      = [aws_security_group.tf-allow-ssh-from-home.id]
#   tags = {
#     Name = "TF_Instance"
#   }
# }
