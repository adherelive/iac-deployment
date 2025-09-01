#!/bin/bash

# deploy-infrastructure.sh - AdhereLive Azure Infrastructure Deployment Script
# Usage: ./deploy-infrastructure.sh [plan|apply|destroy|init] [environment]

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR"
ACTION=${1:-plan}
ENVIRONMENT=${2:-dev} # Default to 'dev' environment

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

# Validate inputs
validate_inputs() {
    if [[ ! "$ACTION" =~ ^(plan|apply|destroy|init)$ ]]; then
        error "Invalid action. Use: plan, apply, destroy, or init"
    fi

    if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
        error "Invalid environment. Use: dev, staging, or prod"
    fi
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."

    if ! command -v terraform &> /dev/null; then
        error "Terraform is not installed. Please install Terraform first."
    fi

    if ! command -v az &> /dev/null; then
        error "Azure CLI is not installed. Please install Azure CLI first."
    fi

    if ! az account show &> /dev/null; then
        error "Azure credentials not configured or expired. Please run 'az login'."
    fi

    if [[ ! -f "$TERRAFORM_DIR/main.tf" ]]; then
        warn "main.tf not found in $TERRAFORM_DIR. This might be okay if you are just initializing."
    fi

    success "Prerequisites check passed"
}

# Create terraform.tfvars if it doesn't exist
create_tfvars() {
    local tfvars_file="$TERRAFORM_DIR/terraform.tfvars"

    if [[ ! -f "$tfvars_file" ]]; then
        log "Creating terraform.tfvars file..."

        # Generate a random suffix for resources
        local random_suffix=$(openssl rand -hex 4)

        cat > "$tfvars_file" << EOF
# terraform.tfvars - Environment-specific variables
# Customize these variables for your environment

# General Configuration
location            = "East US"
environment         = "$ENVIRONMENT"
resource_group_name = "adherelive-${ENVIRONMENT}-rg"
key_vault_name      = "adherelive-${ENVIRONMENT}-kv-${random_suffix}"

# SSH key for VM access - REPLACE THIS with your public key
ssh_public_key = "~/.ssh/id_rsa.pub"

# Your IP address for SSH access - REPLACE THIS with your IP
# You can get your IP from https://www.whatismyip.com/
my_ip_address = "0.0.0.0/0" # WARNING: This is insecure. Please restrict to your IP.

# VM Configuration
vm_size = "Standard_B2s"

# GitHub repository for cloning code
github_repo_fe = "git@github.com:adherelive/adherelive-fe.git"
github_repo_be = "git@github.com:adherelive/adherelive-be.git"

EOF

        warn "terraform.tfvars created with default values."
        warn "Please review and update the values, especially 'ssh_public_key' and 'my_ip_address'!"
        warn "File location: $tfvars_file"
        echo ""
        read -p "Press Enter to continue after reviewing terraform.tfvars..."
    fi
}

# Initialize Terraform
terraform_init() {
    log "Initializing Terraform..."
    cd "$TERRAFORM_DIR"

    # The -backend-config option can be used here if using remote state
    terraform init -upgrade

    success "Terraform initialized"
}

# Validate Terraform configuration
terraform_validate() {
    log "Validating Terraform configuration..."
    cd "$TERRAFORM_DIR"

    terraform validate

    success "Terraform configuration is valid"
}

# Format Terraform files
terraform_format() {
    log "Formatting Terraform files..."
    cd "$TERRAFORM_DIR"

    terraform fmt -recursive

    success "Terraform files formatted"
}

# Plan Terraform changes
terraform_plan() {
    log "Planning Terraform changes..."
    cd "$TERRAFORM_DIR"

    terraform plan -var-file="terraform.tfvars" -out="tfplan"

    success "Terraform plan completed"
}

# Apply Terraform changes
terraform_apply() {
    log "Applying Terraform changes..."
    cd "$TERRAFORM_DIR"

    if [[ ! -f "tfplan" ]]; then
       warn "No tfplan file found. Running plan first."
       terraform_plan
    fi

    log "Applying plan..."
    terraform apply -auto-approve "tfplan"

    success "Terraform apply completed"
}

# Destroy Terraform resources
terraform_destroy() {
    warn "This will destroy ALL infrastructure resources in the '$ENVIRONMENT' environment!"
    echo ""
    read -p "Are you sure you want to destroy the $ENVIRONMENT environment? (type 'yes' to confirm): " confirm

    if [[ "$confirm" == "yes" ]]; then
        log "Destroying Terraform resources..."
        cd "$TERRAFORM_DIR"

        terraform destroy -var-file="terraform.tfvars" -auto-approve

        success "Terraform destroy completed"
    else
        log "Destroy cancelled"
        exit 0
    fi
}

# Show outputs
show_outputs() {
    log "Terraform outputs:"
    cd "$TERRAFORM_DIR"

    terraform output
}

# Main execution
main() {
    log "AdhereLive Azure Infrastructure Deployment"
    log "Action: $ACTION | Environment: $ENVIRONMENT"
    echo ""

    validate_inputs
    check_prerequisites

    case $ACTION in
        init)
            terraform_init
            terraform_validate
            terraform_format
            ;;
        plan)
            create_tfvars
            terraform_init
            terraform_validate
            terraform_format
            terraform_plan
            ;;
        apply)
            create_tfvars
            terraform_init
            terraform_validate
            terraform_format
            terraform_apply
            show_outputs
            ;;
        destroy)
            terraform_destroy
            ;;
        *)
            error "Unknown action: $ACTION"
            ;;
    esac

    success "Deployment script completed successfully!"
}

# Run main function
main "$@"
