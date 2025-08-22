#!/bin/bash

# deploy.sh - Root deployment script for AdhereLive Infrastructure
# This script acts as a wrapper to deploy infrastructure to different cloud providers.
# Usage: ./deploy.sh [aws|azure] [plan|apply|destroy|init]

set -e

# --- Configuration ---
PROVIDER=$1
ACTION=${2:-plan} # Default to 'plan' if no action is provided
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

show_usage() {
    echo "Usage: $0 [aws|azure] [action]"
    echo "Deploys the AdhereLive infrastructure to the specified cloud provider."
    echo ""
    echo "Providers:"
    echo "  aws      - Deploy to Amazon Web Services."
    echo "  azure    - Deploy to Microsoft Azure. (Not yet implemented)"
    echo ""
    echo "Actions:"
    echo "  init     - Initialize Terraform for the selected provider."
    echo "  plan     - (Default) Create a Terraform execution plan."
    echo "  apply    - Apply the Terraform plan to create infrastructure."
    echo "  destroy  - Destroy the Terraform-managed infrastructure."
    echo ""
    echo "Example:"
    echo "  $0 aws apply"
}

# --- Main Logic ---
main() {
    log "AdhereLive Root Deployment Script"
    log "Provider: $PROVIDER | Action: $ACTION"
    echo ""

    # Validate provider input
    if [[ -z "$PROVIDER" ]]; then
        error "No cloud provider specified."
        show_usage
        exit 1
    fi

    if [[ "$PROVIDER" != "aws" && "$PROVIDER" != "azure" ]]; then
        error "Invalid provider: '$PROVIDER'. Please use 'aws' or 'azure'."
        show_usage
        exit 1
    fi

    # --- Provider-specific logic ---
    case $PROVIDER in
        aws)
            log "Executing AWS deployment..."
            AWS_SCRIPT_PATH="$SCRIPT_DIR/aws/deploy-infrastructure.sh"

            if [[ ! -f "$AWS_SCRIPT_PATH" ]]; then
                error "AWS deployment script not found at: $AWS_SCRIPT_PATH"
            fi

            # Pass all arguments from the 2nd one onwards to the AWS script
            cd "$SCRIPT_DIR/aws"
            ./deploy-infrastructure.sh "${@:2}"
            success "AWS deployment script finished."
            ;;

        azure)
            log "Verifying Azure configuration..."
            AZURE_TF_FILE="$SCRIPT_DIR/azure/main.tf"
            AZURE_SCRIPT_PATH="$SCRIPT_DIR/azure/deploy-infrastructure.sh" # Assuming a similar script name

            if [[ ! -f "$AZURE_TF_FILE" ]]; then
                error "Azure Terraform configuration file not found at: $AZURE_TF_FILE"
            fi

            # Check if the main.tf file is actually an AWS file
            if grep -q 'provider "aws"' "$AZURE_TF_FILE" || grep -q 'hashicorp/aws' "$AZURE_TF_FILE"; then
                error "Azure configuration file '$AZURE_TF_FILE' appears to be an AWS configuration."
                error "Please ensure the correct Terraform files for Azure are in place."
                exit 1
            fi

            if [[ ! -f "$AZURE_SCRIPT_PATH" ]]; then
                error "Azure deployment script not found at: $AZURE_SCRIPT_PATH"
                error "A deployment script (e.g., deploy-infrastructure.sh) is required in the 'azure' directory."
                exit 1
            fi

            # If checks pass, proceed with deployment (this part will fail for now)
            log "Executing Azure deployment..."
            cd "$SCRIPT_DIR/azure"
            ./deploy-infrastructure.sh "${@:2}"
            success "Azure deployment script finished."
            ;;
    esac
}

# --- Script Execution ---
main "$@"
