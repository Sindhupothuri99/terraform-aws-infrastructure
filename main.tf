provider "aws" {
  region = "ap-south-1"
}

# Create VPC
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "terraform-devops-vpc"
  }
}

# Create Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "terraform-public-subnet"
  }
}

# Create Private Subnet
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.20.2.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "terraform-private-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "terraform-igw"
  }
}

# Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "terraform-public-route-table"
  }
}

# Associate Public Subnet
resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}
# Security Group for EC2
resource "aws_security_group" "web_sg" {
  name        = "terraform-web-security-group"
  description = "Allow SSH and HTTP traffic"
  vpc_id      = aws_vpc.main_vpc.id

  # SSH - Only your IP
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["110.235.236.56/32"]
  }

  # HTTP - Public access
  ingress {
    description = "HTTP access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-web-security-group"
  }
}

# Find latest Ubuntu 24.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Create EC2 Instance
resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = "laptopkey-01"

  associate_public_ip_address = true

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y nginx
    systemctl enable nginx
    systemctl start nginx
    echo "<h1>Welcome to My Terraform DevOps Project</h1>" > /var/www/html/index.html
  EOF

  tags = {
    Name        = "terraform-devops-server"
    Environment = "Development"
  }
}

# Display EC2 Public IP
output "ec2_public_ip" {
  value = aws_instance.web_server.public_ip
}

# Display EC2 Public DNS
output "ec2_public_dns" {
  value = aws_instance.web_server.public_dns
}