#!/bin/bash
WORK_DIR="/home/zonzo/workindir"
# Ask for project directory and read it into Work Directory
read -p "Enter project directory path [/home/zonzo/workindir/yourprojectname]: " input # reads project directory name and pass it PROJECT_DIR
PROJECT_DIR="${input:-$WORK_DIR/}"

# Logging Module
cat > $PROJECT_DIR/modules/logging/main.tf <<'EOF'
resource "aws_s3_bucket" "flow_logs" {
  bucket = "${var.prefix}-flow-logs-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "${var.prefix}-flow-logs"
    Environment = "prod"
  }
}

resource "aws_s3_bucket_ownership_controls" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name = "${var.prefix}-vpc-flow-logs"
}

resource "aws_flow_log" "s3" {
  log_destination      = aws_s3_bucket.flow_logs.arn
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id              = var.vpc_id
}

resource "aws_flow_log" "cloudwatch" {
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  log_destination_type = "cloudwatch-logs"
  traffic_type         = "ALL"
  vpc_id              = var.vpc_id
}

data "aws_caller_identity" "current" {}
EOF

cat > $PROJECT_DIR/modules/logging/variables.tf <<'EOF'
variable "vpc_id" {
  description = "VPC ID for flow logs"
  type        = string
}

variable "prefix" {
  description = "Resource naming prefix"
  type        = string
}
EOF

cat > $PROJECT_DIR/modules/logging/outputs.tf <<'EOF'
output "s3_bucket_arn" {
  description = "ARN of the flow logs S3 bucket"
  value       = aws_s3_bucket.flow_logs.arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.vpc_flow_logs.name
}
EOF

# Prod Compute Module (updated for 2 instances)
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
  count         = 2
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id     = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = [aws_security_group.instance.id]

  tags = {
    Name = "${var.prefix}-instance-${count.index + 1}"
  }
}
EOF

# Prod Environment
cat > $PROJECT_DIR/environments/prod/main.tf <<'EOF'
module "networking" {
  source      = "../../modules/networking"
  prefix      = "poc-prod"
  environment = "prod"
  aws_region  = var.aws_region
  vpc_cidr    = var.vpc_cidr
}

module "compute" {
  source      = "../../modules/compute"
  prefix      = "poc-prod"
  environment = "prod"
  vpc_id      = module.networking.vpc_id
  subnet_ids  = module.networking.public_subnet_ids
}

module "logging" {
  source  = "../../modules/logging"
  vpc_id  = module.networking.vpc_id
  prefix  = "poc-prod"
}
EOF

cat > $PROJECT_DIR/environments/prod/variables.tf <<'EOF'
variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}
EOF

cat > $PROJECT_DIR/environments/prod/outputs.tf <<'EOF'
output "vpc_id" {
  description = "ID of the created VPC"
  value       = module.networking.vpc_id
}

output "instance_ips" {
  description = "Private IPs of EC2 instances"
  value       = module.compute.instance_private_ips
}

output "flow_logs_bucket" {
  description = "Flow logs bucket name"
  value       = module.logging.s3_bucket_arn
}
EOF

cat > $PROJECT_DIR/environments/prod/terraform.tfvars <<'EOF'
aws_region = "us-east-1"
vpc_cidr = "10.1.0.0/16"
EOF

cat > $PROJECT_DIR/environments/prod/backend.conf <<'EOF'
bucket = "terraform-state-poc-prod"
key    = "terraform.tfstate"
region = "us-east-1"
dynamodb_table = "terraform-lock-prod"
EOF

echo "Production templates generated successfully ✅"