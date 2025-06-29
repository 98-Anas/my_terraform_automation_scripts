#!/bin/bash
WORK_DIR="/home/zonzo/workindir"
# Ask for project directory and read it into Work Directory
read -p "Enter project directory path [/home/zonzo/workindir/yourprojectname]: " input # reads project directory name and pass it PROJECT_DIR
PROJECT_DIR="${input:-$WORK_DIR/}"

# Networking Module
cat > $PROJECT_DIR/modules/networking/main.tf <<'EOF'
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.prefix}-vpc"
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "${var.prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  count                   = 1
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.prefix}-public-subnet-${count.index + 1}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = 1
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
EOF

cat > $PROJECT_DIR/modules/networking/variables.tf <<'EOF'
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "prefix" {
  description = "Resource naming prefix"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}
EOF

cat > $PROJECT_DIR/modules/networking/outputs.tf <<'EOF'
output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "route_table_id" {
  description = "ID of public route table"
  value       = aws_route_table.public.id
}
EOF

# Compute Module
cat > $PROJECT_DIR/modules/compute/main.tf <<'EOF'
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  owners = ["099720109477"]
}

resource "aws_security_group" "instance" {
  name        = "${var.prefix}-instance-sg"
  description = "Allow SSH and HTTP traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.prefix}-instance-sg"
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.instance.id]

  tags = {
    Name = "${var.prefix}-instance-1"
  }
}
EOF

cat > $PROJECT_DIR/modules/compute/variables.tf <<'EOF'
variable "vpc_id" {
  description = "VPC ID for instances"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for instances"
  type        = list(string)
}

variable "prefix" {
  description = "Resource naming prefix"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}
EOF

cat > $PROJECT_DIR/modules/compute/outputs.tf <<'EOF'
output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.web.public_ip
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.instance.id
}
EOF

# Pre-Prod Environment
cat > $PROJECT_DIR/environments/pre-prod/main.tf <<'EOF'
module "networking" {
  source      = "../../modules/networking"
  prefix      = "poc-pre-prod"
  environment = "pre-prod"
  aws_region  = var.aws_region
  vpc_cidr    = var.vpc_cidr
}

module "compute" {
  source      = "../../modules/compute"
  prefix      = "poc-pre-prod"
  environment = "pre-prod"
  vpc_id      = module.networking.vpc_id
  subnet_ids  = module.networking.public_subnet_ids
}
EOF

cat > $PROJECT_DIR/environments/pre-prod/variables.tf <<'EOF'
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}
EOF

cat > $PROJECT_DIR/environments/pre-prod/outputs.tf <<'EOF'
output "vpc_id" {
  description = "ID of the created VPC"
  value       = module.networking.vpc_id
}

output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = module.compute.instance_public_ip
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.networking.public_subnet_ids
}
EOF

cat > $PROJECT_DIR/environments/pre-prod/terraform.tfvars <<'EOF'
aws_region = "us-east-1"
vpc_cidr = "10.0.0.0/16"
EOF

cat > $PROJECT_DIR/environments/pre-prod/backend.conf <<'EOF'
bucket = "terraform-state-poc-pre-prod"
key    = "terraform.tfstate"
region = "us-east-1"
EOF

echo "Pre-production templates generated successfully ✅"