#!/bin/bash
# AWS Bootstrap Script for Robo Stack
# This script prepares your local environment and applies Terraform infrastructure

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")/terraform"
SSH_KEY_PATH="$HOME/.ssh/robo-stack-dev.pem"

log_info "Robo Stack AWS Bootstrap Script"
log_info "================================"
log_info "Script directory: $SCRIPT_DIR"
log_info "Terraform directory: $TERRAFORM_DIR"
echo ""

# Check prerequisites
log_info "Checking prerequisites..."

# Check Terraform
if ! command -v terraform &> /dev/null; then
    log_error "Terraform is not installed"
    log_info "Install from: https://www.terraform.io/downloads.html"
    exit 1
fi

TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
log_success "Terraform $TERRAFORM_VERSION found"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI is not installed"
    log_info "Install from: https://aws.amazon.com/cli/"
    exit 1
fi

AWS_CLI_VERSION=$(aws --version | cut -d' ' -f1)
log_success "AWS CLI $AWS_CLI_VERSION found"

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials not configured or invalid"
    log_info "Run: aws configure"
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_USER=$(aws sts get-caller-identity --query Arn --output text)
log_success "AWS credentials valid"
log_info "Account ID: $AWS_ACCOUNT_ID"
log_info "User: $AWS_USER"
echo ""

# Check jq
if ! command -v jq &> /dev/null; then
    log_warning "jq not found, installing..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get install -qq -y jq
    elif command -v brew &> /dev/null; then
        brew install jq
    else
        log_error "Cannot install jq automatically. Please install manually."
        exit 1
    fi
fi

# Generate SSH key if it doesn't exist
log_info "Checking SSH key..."
if [ ! -f "$SSH_KEY_PATH" ]; then
    log_warning "SSH key not found at $SSH_KEY_PATH"
    log_info "Generating new SSH key pair..."

    mkdir -p "$HOME/.ssh"
    ssh-keygen -t ed25519 \
        -f "$SSH_KEY_PATH" \
        -N "" \
        -C "robo-stack-dev@$(date +%Y-%m-%d)" \
        -q

    chmod 600 "$SSH_KEY_PATH"
    chmod 644 "$SSH_KEY_PATH.pub"

    log_success "SSH key generated at $SSH_KEY_PATH"
else
    log_success "SSH key already exists at $SSH_KEY_PATH"
fi

echo ""

# Check terraform.tfvars
log_info "Checking terraform.tfvars..."
TFVARS_FILE="$TERRAFORM_DIR/terraform.tfvars"

if [ ! -f "$TFVARS_FILE" ]; then
    log_warning "terraform.tfvars not found"
    log_info "Creating from example..."

    if [ ! -f "$TERRAFORM_DIR/terraform.tfvars.example" ]; then
        log_error "terraform.tfvars.example not found at $TERRAFORM_DIR"
        exit 1
    fi

    cp "$TERRAFORM_DIR/terraform.tfvars.example" "$TFVARS_FILE"
    log_warning "IMPORTANT: Edit $TFVARS_FILE and set your allowed_ssh_cidr"
    log_info ""
    log_info "To find your public IP:"
    log_info "  curl -s https://ifconfig.me"
    log_info ""
    log_info "Then edit the file:"
    log_info "  nano $TFVARS_FILE"
    log_info ""

    echo -n "Press Enter when you've edited terraform.tfvars: "
    read -r

    if ! grep -q "allowed_ssh_cidr.*=" "$TFVARS_FILE"; then
        log_error "terraform.tfvars not properly configured"
        exit 1
    fi
else
    log_success "terraform.tfvars found"

    # Extract and display current settings
    REGION=$(grep "aws_region" "$TFVARS_FILE" | grep -oP '"\K[^"]+' | head -1)
    ALLOWED_SSH=$(grep "allowed_ssh_cidr" "$TFVARS_FILE" | grep -oP '"\K[^"]+' | head -1)

    log_info "Current configuration:"
    log_info "  AWS Region: $REGION"
    log_info "  Allowed SSH CIDR: $ALLOWED_SSH"
fi

echo ""

# Initialize Terraform
log_info "Initializing Terraform..."
cd "$TERRAFORM_DIR"

if [ ! -d ".terraform" ]; then
    terraform init -input=false
    log_success "Terraform initialized"
else
    log_success "Terraform already initialized"
fi

echo ""

# Validate Terraform
log_info "Validating Terraform configuration..."
if terraform validate; then
    log_success "Terraform configuration is valid"
else
    log_error "Terraform validation failed"
    exit 1
fi

echo ""

# Run terraform plan
log_info "Running terraform plan..."
log_info "(This may take 1-2 minutes)"

PLAN_FILE="tfplan-$(date +%s)"
if terraform plan -out="$PLAN_FILE" -input=false; then
    log_success "Terraform plan succeeded"
else
    log_error "Terraform plan failed"
    rm -f "$PLAN_FILE"
    exit 1
fi

echo ""
log_info "Plan summary:"
terraform show "$PLAN_FILE" | grep -E "^(aws_|Plan:)" | head -20

echo ""

# Ask for confirmation
log_warning "Review the plan above carefully!"
echo ""
echo -n "Do you want to apply these changes? (yes/no): "
read -r CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    log_warning "Terraform apply cancelled"
    log_info "Plan saved to: $PLAN_FILE"
    log_info "To apply later, run: terraform apply $PLAN_FILE"
    rm -f "$PLAN_FILE"
    exit 0
fi

echo ""

# Apply Terraform
log_info "Applying Terraform configuration..."
log_info "(This will take 2-5 minutes)"

if terraform apply "$PLAN_FILE"; then
    log_success "Terraform apply succeeded!"
    rm -f "$PLAN_FILE"
else
    log_error "Terraform apply failed"
    log_warning "Plan saved to: $PLAN_FILE"
    log_info "To retry, run: terraform apply $PLAN_FILE"
    exit 1
fi

echo ""
echo "================================================================"
log_success "Infrastructure deployed successfully!"
echo "================================================================"
echo ""

# Get outputs
log_info "Extracting deployment information..."

INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null || echo "N/A")
INSTANCE_IP=$(terraform output -raw instance_public_ip 2>/dev/null || echo "N/A")
K8S_ENDPOINT=$(terraform output -raw k8s_api_endpoint 2>/dev/null || echo "N/A")
SSH_COMMAND=$(terraform output -raw ssh_command 2>/dev/null || echo "N/A")

echo ""
echo -e "${BLUE}=== Deployment Information ===${NC}"
echo "Instance ID:      $INSTANCE_ID"
echo "Public IP:        $INSTANCE_IP"
echo "K8s API:          $K8S_ENDPOINT"
echo "SSH Key:          $SSH_KEY_PATH"
echo ""

echo -e "${BLUE}=== Connection Details ===${NC}"
echo "To connect to your workstation:"
echo ""
echo "  $SSH_COMMAND"
echo ""

echo -e "${BLUE}=== Initialization Time ===${NC}"
echo "⏱  K3s and tools are installing in the background (3-5 minutes)"
echo ""
echo "Check initialization status with:"
echo "  $SSH_COMMAND"
echo "  sudo systemctl status k3s"
echo "  kubectl get nodes"
echo ""

echo -e "${BLUE}=== Access Kubernetes ===${NC}"
echo "On the instance:"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
echo "  cat ~/.kube/config"
echo ""

echo "From your local machine (with kubectl):"
echo "  # Copy kubeconfig locally"
echo "  scp -i $SSH_KEY_PATH ubuntu@$INSTANCE_IP:/home/ubuntu/.kube/config ~/.kube/config-robo-stack"
echo ""
echo "  # Or use kubectl proxy"
echo "  ssh -i $SSH_KEY_PATH -L 6443:localhost:6443 ubuntu@$INSTANCE_IP -N &"
echo "  kubectl --kubeconfig ~/.kube/config-robo-stack cluster-info"
echo ""

echo -e "${BLUE}=== Monitoring ===${NC}"
echo "Check cloud-init bootstrap progress:"
echo "  $SSH_COMMAND"
echo "  tail -f /var/log/cloud-init-output.log"
echo ""

echo -e "${BLUE}=== Next Steps ===${NC}"
echo "1. Wait 3-5 minutes for K3s to fully initialize"
echo "2. SSH into the instance: $SSH_COMMAND"
echo "3. Verify K3s is running: sudo systemctl status k3s"
echo "4. Deploy your first application!"
echo ""

echo -e "${BLUE}=== Cleanup ===${NC}"
echo "To destroy all infrastructure and stop charges:"
echo ""
echo "  cd $TERRAFORM_DIR"
echo "  terraform destroy"
echo ""

# Save output to file
OUTPUT_FILE="$TERRAFORM_DIR/deployment-info.txt"
cat > "$OUTPUT_FILE" << EOF
Robo Stack AWS Deployment Information
=====================================
Generated: $(date)

Instance ID:       $INSTANCE_ID
Public IP:         $INSTANCE_IP
K8s API Endpoint:  $K8S_ENDPOINT
SSH Key Path:      $SSH_KEY_PATH

SSH Command:
$SSH_COMMAND

K8s API Command (from local machine):
ssh -i $SSH_KEY_PATH -L 6443:localhost:6443 ubuntu@$INSTANCE_IP -N

Installation Status:
- Check with: tail -f /var/log/cloud-init-output.log
- K3s should be ready in 3-5 minutes

Cleanup:
terraform destroy

EOF

log_success "Deployment info saved to: $OUTPUT_FILE"
echo ""

# Display terraform output
echo -e "${BLUE}=== Full Terraform Output ===${NC}"
terraform output

echo ""
log_success "Bootstrap complete!"
