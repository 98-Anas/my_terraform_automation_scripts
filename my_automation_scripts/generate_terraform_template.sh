#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Template directory path
TEMPLATE_DIR="${SCRIPT_DIR}/template"

echo "Creating AWS Landing Zone template structure..."
echo "Template directory: ${TEMPLATE_DIR}"

# Create template directory and subdirectories
mkdir -p "${TEMPLATE_DIR}"/{.github/workflows,environments/{pre-prod,prod},modules/{networking,compute,logging},scripts,diagrams}

# Root Terraform files
touch "${TEMPLATE_DIR}"/{providers.tf,variables.tf,outputs.tf,backend.tf}

# Environment-specific files
for env in pre-prod prod; do
    touch "${TEMPLATE_DIR}/environments/${env}"/{main.tf,variables.tf,outputs.tf,terraform.tfvars,backend.conf}
done

# Module files
for module in networking compute logging; do
    touch "${TEMPLATE_DIR}/modules/${module}"/{main.tf,variables.tf,outputs.tf}
done

# CI/CD and script files
touch "${TEMPLATE_DIR}/.github/workflows/terraform.yml"
touch "${TEMPLATE_DIR}/diagrams/architecture.py"

# Create empty script files
cat > "${TEMPLATE_DIR}/scripts/generate_preprod_templates.sh" <<'EOF'
#!/bin/bash
echo "Pre-prod template generation"
EOF

cat > "${TEMPLATE_DIR}/scripts/generate_prod_templates.sh" <<'EOF'
#!/bin/bash
echo "Prod template generation"
EOF

cat > "${TEMPLATE_DIR}/scripts/deploy_preprod.sh" <<'EOF'
#!/bin/bash
echo "Pre-prod deployment"
EOF

cat > "${TEMPLATE_DIR}/scripts/deploy_prod.sh" <<'EOF'
#!/bin/bash
echo "Prod deployment"
EOF

# Set executable permissions
chmod +x "${TEMPLATE_DIR}"/scripts/*.sh

# Create basic .gitignore
cat > "${TEMPLATE_DIR}/.gitignore" <<'EOF'
# Local Terraform directories
**/.terraform/*
**/.terraform.lock.hcl

# Terraform state files
*.tfstate
*.tfstate.*

# Crash log files
crash.log
crash.*.log

# Exclude all .tfvars files
*.tfvars
!*.tfvars.example

# Ignore override files
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# Ignore CLI configuration files
.terraformrc
terraform.rc
EOF

echo "✅ Template structure created successfully at ${TEMPLATE_DIR}"
echo " "