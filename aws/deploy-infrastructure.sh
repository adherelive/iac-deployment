#!/bin/bash

# deploy-infrastructure.sh - AdhereLive Infrastructure Deployment Script
# Usage: ./deploy-infrastructure.sh [plan|apply|destroy] [environment]

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR"
ACTION=${1:-plan}
ENVIRONMENT=${2:-prod}

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

    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        error "Terraform is not installed. Please install Terraform first."
    fi

    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        error "AWS CLI is not installed. Please install AWS CLI first."
    fi

    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured. Please run 'aws configure'."
    fi

    # Check if required files exist
    if [[ ! -f "$TERRAFORM_DIR/main.tf" ]]; then
        error "main.tf not found in $TERRAFORM_DIR"
    fi

    success "Prerequisites check passed"
}

# Create terraform.tfvars if it doesn't exist
create_tfvars() {
    local tfvars_file="$TERRAFORM_DIR/terraform.tfvars"
    
    if [[ ! -f "$tfvars_file" ]]; then
        log "Creating terraform.tfvars file..."
        
        cat > "$tfvars_file" << EOF
# terraform.tfvars - Environment-specific variables
# Copy this file and customize for your environment

# General Configuration
aws_region  = "ap-south-1"
environment = "$ENVIRONMENT"

# Domain Configuration
domain_name = "adhere.live"
subdomain   = "test"

# Database Passwords (CHANGE THESE!)
mysql_password   = "$(openssl rand -base64 32)"
mongodb_password = "$(openssl rand -base64 32)"

# Application Images (update these when deploying)
backend_image  = "adherelive-be:$ENVIRONMENT"
frontend_image = "adherelive-fe:$ENVIRONMENT"

# Scaling Configuration
backend_desired_count  = 2
frontend_desired_count = 2

# Database Configuration
rds_instance_class        = "db.t3.micro"
documentdb_instance_class = "db.t3.medium"

# Multi-AZ and backup settings
enable_multi_az           = false  # Set to true for production
backup_retention_period   = 7      # Days
enable_cross_region_backup = false # Set to true for DR
EOF

        warn "terraform.tfvars created with default values."
        warn "Please review and update the values, especially passwords!"
        warn "File location: $tfvars_file"
        echo ""
        read -p "Press Enter to continue after reviewing terraform.tfvars..."
    fi
}

# Initialize Terraform
terraform_init() {
    log "Initializing Terraform..."
    cd "$TERRAFORM_DIR"
    
    terraform init
    
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
    
    if [[ -f "tfplan" ]]; then
        terraform apply "tfplan"
    else
        warn "No plan file found. Creating new plan..."
        terraform plan -var-file="terraform.tfvars" -out="tfplan"
        echo ""
        read -p "Do you want to apply these changes? (yes/no): " confirm
        if [[ "$confirm" == "yes" ]]; then
            terraform apply "tfplan"
        else
            log "Apply cancelled"
            exit 0
        fi
    fi
    
    success "Terraform apply completed"
}

# Destroy Terraform resources
terraform_destroy() {
    warn "This will destroy ALL infrastructure resources!"
    echo ""
    read -p "Are you sure you want to destroy the $ENVIRONMENT environment? (type 'yes' to confirm): " confirm
    
    if [[ "$confirm" == "yes" ]]; then
        log "Destroying Terraform resources..."
        cd "$TERRAFORM_DIR"
        
        terraform destroy -var-file="terraform.tfvars"
        
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
    log "AdhereLive Infrastructure Deployment"
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