#!/bin/bash

# deploy-infrastructure.sh - Azure Deployment Script
# This script initializes and runs Terraform for the Azure environment.

set -e

# --- Colors for output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Helper Functions ---
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# --- Main Logic ---
ACTION=${1:-plan} # Default to 'plan' if no action is provided

log "Initializing Terraform for Azure..."
terraform init -upgrade

case $ACTION in
    plan)
        log "Creating Terraform plan..."
        terraform plan -out=tfplan
        ;;
    apply)
        log "Applying Terraform plan..."
        terraform apply -auto-approve tfplan
        ;;
    destroy)
        log "Destroying Terraform-managed infrastructure..."
        terraform destroy -auto-approve
        ;;
    init)
        log "Terraform has already been initialized."
        ;;
    *)
        error "Invalid action: '$ACTION'. Please use 'plan', 'apply', 'destroy', or 'init'."
        ;;
esac

log "Azure script finished."
