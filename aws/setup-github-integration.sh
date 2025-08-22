#!/bin/bash

# setup-github-integration.sh - Setup GitHub Integration for CodeBuild
# This script helps configure GitHub access for private repositories

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="ap-south-1"
SECRET_NAME_PREFIX="adherelive-prod"

# Logging functions
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

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."

    if ! command -v aws &> /dev/null; then
        error "AWS CLI is not installed. Please install AWS CLI first."
    fi

    if ! command -v git &> /dev/null; then
        error "Git is not installed. Please install Git first."
    fi

    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured. Please run 'aws configure'."
    fi

    success "Prerequisites check passed"
}

# Generate SSH key pair for GitHub
generate_ssh_key() {
    log "Generating SSH key pair for GitHub access..."
    
    local ssh_dir="$HOME/.ssh"
    local key_name="adherelive_github_rsa"
    local private_key_path="$ssh_dir/$key_name"
    local public_key_path="$ssh_dir/$key_name.pub"
    
    # Create .ssh directory if it doesn't exist
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    
    # Generate SSH key pair if it doesn't exist
    if [[ ! -f "$private_key_path" ]]; then
        log "Generating new SSH key pair..."
        ssh-keygen -t rsa -b 4096 -C "adherelive-codebuild@adhere.live" -f "$private_key_path" -N ""
        chmod 600 "$private_key_path"
        chmod 644 "$public_key_path"
        success "SSH key pair generated successfully"
    else
        log "SSH key pair already exists"
    fi
    
    echo "$private_key_path"
}

# Create GitHub Personal Access Token instructions
create_github_token_instructions() {
    log "GitHub Personal Access Token Setup Instructions:"
    echo ""
    echo "1. Go to https://github.com/settings/tokens"
    echo "2. Click 'Generate new token' -> 'Generate new token (classic)'"
    echo "3. Give it a descriptive name: 'AdhereLive CodeBuild Access'"
    echo "4. Set expiration as needed (recommend 90 days for testing)"
    echo "5. Select the following scopes:"
    echo "   ✓ repo (Full control of private repositories)"
    echo "   ✓ admin:repo_hook (Read and write repository hooks)"
    echo "6. Click 'Generate token'"
    echo "7. Copy the token immediately (you won't see it again)"
    echo ""
    warn "Keep this token secure and don't share it!"
    echo ""
}

# Store GitHub token in Secrets Manager
store_github_token() {
    local secret_name="${SECRET_NAME_PREFIX}-github-token"
    
    create_github_token_instructions
    
    echo -n "Enter your GitHub Personal Access Token: "
    read -s github_token
    echo ""
    
    if [[ -z "$github_token" ]]; then
        error "GitHub token cannot be empty"
    fi
    
    log "Storing GitHub token in AWS Secrets Manager..."
    
    # Check if secret exists
    if aws secretsmanager describe-secret --secret-id "$secret_name" --region "$AWS_REGION" &>/dev/null; then
        log "Secret already exists, updating..."
        aws secretsmanager update-secret \
            --secret-id "$secret_name" \
            --secret-string "$github_token" \
            --region "$AWS_REGION" > /dev/null
    else
        log "Creating new secret..."
        aws secretsmanager create-secret \
            --name "$secret_name" \
            --description "GitHub Personal Access Token for AdhereLive CodeBuild" \
            --secret-string "$github_token" \
            --region "$AWS_REGION" > /dev/null
    fi
    
    success "GitHub token stored successfully in Secrets Manager"
}

# Store SSH private key in Secrets Manager
store_ssh_key() {
    local private_key_path=$1
    local secret_name="${SECRET_NAME_PREFIX}-ssh-private-key"
    
    if [[ ! -f "$private_key_path" ]]; then
        error "SSH private key not found at $private_key_path"
    fi
    
    log "Storing SSH private key in AWS Secrets Manager..."
    
    # Read the private key content
    local private_key_content=$(cat "$private_key_path")
    
    # Check if secret exists
    if aws secretsmanager describe-secret --secret-id "$secret_name" --region "$AWS_REGION" &>/dev/null; then
        log "Secret already exists, updating..."
        aws secretsmanager update-secret \
            --secret-id "$secret_name" \
            --secret-string "$private_key_content" \
            --region "$AWS_REGION" > /dev/null
    else
        log "Creating new secret..."
        aws secretsmanager create-secret \
            --name "$secret_name" \
            --description "SSH Private Key for GitHub access" \
            --secret-string "$private_key_content" \
            --region "$AWS_REGION" > /dev/null
    fi
    
    success "SSH private key stored successfully in Secrets Manager"
}

# Add SSH key to GitHub instructions
add_ssh_key_to_github_instructions() {
    local public_key_path=$1
    
    log "Adding SSH Key to GitHub Instructions:"
    echo ""
    echo "1. Copy the public key below:"
    echo "----------------------------------------"
    cat "$public_key_path"
    echo "----------------------------------------"
    echo ""
    echo "2. Go to https://github.com/settings/ssh/new"
    echo "3. Give it a title: 'AdhereLive CodeBuild SSH Key'"
    echo "4. Paste the public key in the 'Key' field"
    echo "5. Click 'Add SSH key'"
    echo ""
    echo "6. Add the SSH key to your repository deploy keys:"
    echo "   - Go to https://github.com/adherelive/adherelive-web/settings/keys"
    echo "   - Click 'Add deploy key'"
    echo "   - Title: 'AdhereLive CodeBuild'"
    echo "   - Paste the same public key"
    echo "   - Check 'Allow write access' if you need push access"
    echo "   - Click 'Add key'"
    echo ""
    echo "   - Repeat for https://github.com/adherelive/adherelive-fe/settings/keys"
    echo ""
}

# Test repository access
test_repository_access() {
    log "Testing repository access..."
    
    local test_repos=(
        "git@github.com:adherelive/adherelive-web.git"
        "git@github.com:adherelive/adherelive-fe.git"
    )
    
    for repo in "${test_repos[@]}"; do
        log "Testing access to $repo..."
        if git ls-remote "$repo" HEAD &>/dev/null; then
            success "✓ Access confirmed for $repo"
        else
            warn "✗ Cannot access $repo - check SSH key setup"
        fi
    done
}

# Create buildspec files in repositories
create_buildspec_files() {
    log "Creating buildspec files for repositories..."
    
    # Backend buildspec
    cat > buildspec-backend.yml << 'EOF'
version: 0.2

phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
      - REPOSITORY_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME
      - COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - IMAGE_TAG_COMMIT=${IMAGE_TAG:-latest}-${COMMIT_HASH}
      
  build:
    commands:
      - echo Build started on `date`
      - echo Building the Docker image...
      - docker build -t $IMAGE_REPO_NAME:$IMAGE_TAG .
      - docker tag $IMAGE_REPO_NAME:$IMAGE_TAG $REPOSITORY_URI:$IMAGE_TAG
      - docker tag $IMAGE_REPO_NAME:$IMAGE_TAG $REPOSITORY_URI:$IMAGE_TAG_COMMIT
      - docker tag $IMAGE_REPO_NAME:$IMAGE_TAG $REPOSITORY_URI:latest
      
  post_build:
    commands:
      - echo Build completed on `date`
      - echo Pushing the Docker images...
      - docker push $REPOSITORY_URI:$IMAGE_TAG
      - docker push $REPOSITORY_URI:$IMAGE_TAG_COMMIT
      - docker push $REPOSITORY_URI:latest
      - printf '[{"name":"backend","imageUri":"%s"}]' $REPOSITORY_URI:$IMAGE_TAG > imagedefinitions.json

artifacts:
  files:
    - imagedefinitions.json
EOF

    # Frontend buildspec
    cat > buildspec-frontend.yml << 'EOF'
version: 0.2

phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
      - REPOSITORY_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME
      - COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - IMAGE_TAG_COMMIT=${IMAGE_TAG:-latest}-${COMMIT_HASH}
      
  build:
    commands:
      - echo Build started on `date`
      - echo Building the Docker image...
      - docker build -t $IMAGE_REPO_NAME:$IMAGE_TAG .
      - docker tag $IMAGE_REPO_NAME:$IMAGE_TAG $REPOSITORY_URI:$IMAGE_TAG
      - docker tag $IMAGE_REPO_NAME:$IMAGE_TAG $REPOSITORY_URI:$IMAGE_TAG_COMMIT
      - docker tag $IMAGE_REPO_NAME:$IMAGE_TAG $REPOSITORY_URI:latest
      
  post_build:
    commands:
      - echo Build completed on `date`
      - echo Pushing the Docker images...
      - docker push $REPOSITORY_URI:$IMAGE_TAG
      - docker push $REPOSITORY_URI:$IMAGE_TAG_COMMIT
      - docker push $REPOSITORY_URI:latest
      - printf '[{"name":"frontend","imageUri":"%s"}]' $REPOSITORY_URI:$IMAGE_TAG > imagedefinitions.json

artifacts:
  files:
    - imagedefinitions.json
EOF

    success "Buildspec files created in current directory"
    warn "Copy these files to the root of your respective repositories"
}

# Set up CodeBuild webhook for automatic builds
setup_webhook() {
    local project_name=$1
    
    log "Setting up webhook for $project_name..."
    
    # This would typically be done via Terraform, but we can provide the CLI command
    echo "To set up webhook for automatic builds, run:"
    echo "aws codebuild create-webhook --project-name $project_name --region $AWS_REGION"
}

# Main execution
main() {
    log "AdhereLive GitHub Integration Setup"
    echo ""

    check_prerequisites
    
    # Generate SSH key
    private_key_path=$(generate_ssh_key)
    public_key_path="${private_key_path}.pub"
    
    # Store credentials in Secrets Manager
    store_github_token
    store_ssh_key "$private_key_path"
    
    # Provide instructions for GitHub setup
    add_ssh_key_to_github_instructions "$public_key_path"
    
    # Create buildspec files
    create_buildspec_files
    
    echo ""
    warn "Next steps:"
    echo "1. Add the SSH key to your GitHub account and repository deploy keys"
    echo "2. Copy the buildspec files to your repository roots"
    echo "3. Add appropriate Dockerfiles to your repositories"
    echo "4. Run terraform apply to create the CodeBuild projects"
    echo "5. Test the build by triggering CodeBuild manually"
    echo ""
    
    success "GitHub integration setup completed!"
    
    echo ""
    log "Testing repository access (this may fail until SSH keys are added to GitHub)..."
    test_repository_access
}

# Run main function
main "$@"