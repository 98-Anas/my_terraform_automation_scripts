#!/bin/bash
WORK_DIR="/home/zonzo/workindir"
# Ask for project directory and read it into Work Directory
read -p "Enter project directory path [/home/zonzo/workindir/yourprojectname]: " input # reads project directory name and pass it PROJECT_DIR
PROJECT_DIR="${input:-$WORK_DIR/}"
ENV_DIR="$PROJECT_DIR/environments/prod"

cd $ENV_DIR

echo "Initializing Terraform..."
terraform init -backend-config=backend.conf

echo "Validating configuration..."
terraform validate

echo "Planning deployment..."
terraform plan -out=tfplan

read -p "Apply changes to prod? (y/n) " confirm
if [ "$confirm" = "y" ]; then
  terraform apply tfplan
else
  echo "Deployment cancelled"
fi