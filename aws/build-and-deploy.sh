#!/bin/bash

# build-and-deploy.sh - Automated Build and Deployment Script
# Usage: ./build-and-deploy.sh [environment] [branch] [--auto-yes]

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENVIRONMENT=${1:-prod}
BRANCH=${2:-akshay-gaurav-latest-changes}
AUTO_YES=${3}
AWS_REGION="ap-south-1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
        error "AWS CLI is not installed"
    fi

    if ! command -v terraform &> /dev/null; then
        error "Terraform is not installed"
    fi

    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured"
    fi

    success "Prerequisites check passed"
}

# Get CodeBuild project names from Terraform outputs
get_codebuild_projects() {
    log "Getting CodeBuild project names from Terraform..."
    
    if [[ ! -f "$SCRIPT_DIR/terraform.tfstate" ]]; then
        error "Terraform state not found. Run terraform apply first."
    fi
    
    BACKEND_PROJECT=$(terraform output -raw backend_codebuild_project_name 2>/dev/null || echo "")
    FRONTEND_PROJECT=$(terraform output -raw frontend_codebuild_project_name 2>/dev/null || echo "")
    
    if [[ -z "$BACKEND_PROJECT" ]] || [[ -z "$FRONTEND_PROJECT" ]]; then
        error "CodeBuild projects not found in Terraform state. Deploy infrastructure first."
    fi
    
    log "Backend CodeBuild project: $BACKEND_PROJECT"
    log "Frontend CodeBuild project: $FRONTEND_PROJECT"
}

# Trigger CodeBuild project
trigger_build() {
    local project_name=$1
    local service_name=$2
    
    log "Triggering build for $service_name ($project_name)..."
    
    # Start the build
    BUILD_ID=$(aws codebuild start-build \
        --project-name "$project_name" \
        --source-version "$BRANCH" \
        --region "$AWS_REGION" \
        --query 'build.id' \
        --output text)
    
    if [[ -z "$BUILD_ID" ]]; then
        error "Failed to start build for $service_name"
    fi
    
    log "Build started with ID: $BUILD_ID"
    
    # Monitor build progress
    log "Monitoring build progress for $service_name..."
    
    while true; do
        BUILD_STATUS=$(aws codebuild batch-get-builds \
            --ids "$BUILD_ID" \
            --region "$AWS_REGION" \
            --query 'builds[0].buildStatus' \
            --output text)
        
        case $BUILD_STATUS in
            "IN_PROGRESS")
                echo -n "."
                sleep 10
                ;;
            "SUCCEEDED")
                echo ""
                success "✓ Build completed successfully for $service_name"
                break
                ;;
            "FAILED"|"FAULT"|"STOPPED"|"TIMED_OUT")
                echo ""
                error "✗ Build failed for $service_name with status: $BUILD_STATUS"
                ;;
            *)
                echo ""
                warn "Unknown build status: $BUILD_STATUS"
                sleep 10
                ;;
        esac
    done
    
    # Get build logs
    log "Build logs for $service_name:"
    aws logs get-log-events \
        --log-group-name "/aws/codebuild/$project_name" \
        --log-stream-name "$BUILD_ID" \
        --region "$AWS_REGION" \
        --query 'events[?message != null].message' \
        --output text | tail -20
}

# Update ECS service with new image
update_ecs_service() {
    local service_name=$1
    local cluster_name=$2
    
    log "Updating ECS service: $service_name"
    
    # Force new deployment to pick up the latest image
    aws ecs update-service \
        --cluster "$cluster_name" \
        --service "$service_name" \
        --force-new-deployment \
        --region "$AWS_REGION" > /dev/null
    
    # Wait for deployment to complete
    log "Waiting for deployment to complete..."
    aws ecs wait services-stable \
        --cluster "$cluster_name" \
        --services "$service_name" \
        --region "$AWS_REGION"
    
    success "✓ ECS service $service_name updated successfully"
}

# Get ECS cluster and service names
get_ecs_info() {
    log "Getting ECS cluster and service information..."
    
    ECS_CLUSTER=$(terraform output -raw ecs_cluster_name 2>/dev/null || echo "")
    BACKEND_SERVICE=$(terraform output -raw backend_service_name 2>/dev/null || echo "")
    FRONTEND_SERVICE=$(terraform output -raw frontend_service_name 2>/dev/null || echo "")
    
    if [[ -z "$ECS_CLUSTER" ]] || [[ -z "$BACKEND_SERVICE" ]] || [[ -z "$FRONTEND_SERVICE" ]]; then
        error "ECS information not found in Terraform state"
    fi
    
    log "ECS Cluster: $ECS_CLUSTER"
    log "Backend Service: $BACKEND_SERVICE"
    log "Frontend Service: $FRONTEND_SERVICE"
}

# Verify deployment
verify_deployment() {
    log "Verifying deployment..."
    
    # Get application URL
    APP_URL=$(terraform output -raw application_url 2>/dev/null || echo "")
    
    if [[ -n "$APP_URL" ]]; then
        log "Testing application at: $APP_URL"
        
        # Test frontend
        if curl -s -o /dev/null -w "%{http_code}" "$APP_URL" | grep -q "200"; then
            success "✓ Frontend is responding"
        else
            warn "Frontend may not be fully ready yet"
        fi
        
        # Test backend API
        if curl -s -o /dev/null -w "%{http_code}" "$APP_URL/api/health" | grep -q "200"; then
            success "✓ Backend API is responding"
        else
            warn "Backend API may not be fully ready yet"
        fi
    else
        warn "Application URL not found in Terraform outputs"
    fi
    
    # Check ECS service health
    log "Checking ECS service health..."
    
    BACKEND_HEALTHY=$(aws ecs describe-services \
        --cluster "$ECS_CLUSTER" \
        --services "$BACKEND_SERVICE" \
        --region "$AWS_REGION" \
        --query 'services[0].runningCount' \
        --output text)
    
    FRONTEND_HEALTHY=$(aws ecs describe-services \
        --cluster "$ECS_CLUSTER" \
        --services "$FRONTEND_SERVICE" \
        --region "$AWS_REGION" \
        --query 'services[0].runningCount' \
        --output text)
    
    log "Backend running tasks: $BACKEND_HEALTHY"
    log "Frontend running tasks: $FRONTEND_HEALTHY"
    
    if [[ "$BACKEND_HEALTHY" -gt 0 ]] && [[ "$FRONTEND_HEALTHY" -gt 0 ]]; then
        success "✓ All services are running"
    else
        warn "Some services may not be healthy"
    fi
}

# Show deployment status
show_status() {
    log "Deployment Status Summary:"
    echo ""
    echo "Environment: $ENVIRONMENT"
    echo "Branch: $BRANCH"
    echo "Region: $AWS_REGION"
    echo ""
    
    if [[ -n "$APP_URL" ]]; then
        echo "Application URL: $APP_URL"
    fi
    
    echo "Backend ECR: $(terraform output -raw backend_ecr_repository_url 2>/dev/null || echo 'N/A')"
    echo "Frontend ECR: $(terraform output -raw frontend_ecr_repository_url 2>/dev/null || echo 'N/A')"
    echo ""
    
    log "To monitor your application:"
    echo "- ECS Console: https://console.aws.amazon.com/ecs/home?region=$AWS_REGION#/clusters/$ECS_CLUSTER/services"
    echo "- CloudWatch Logs: https://console.aws.amazon.com/cloudwatch/home?region=$AWS_REGION#logsV2:log-groups"
    echo "- ECR Repositories: https://console.aws.amazon.com/ecr/repositories?region=$AWS_REGION"
}

# Prompt for confirmation
prompt_confirmation() {
    if [[ "$AUTO_YES" == "--auto-yes" ]]; then
        return 0
    fi
    
    echo ""
    warn "This will:"
    echo "1. Trigger builds for both backend and frontend from branch: $BRANCH"
    echo "2. Push new Docker images to ECR"
    echo "3. Update ECS services with new images"
    echo "4. Wait for deployment to complete"
    echo ""
    
    read -p "Do you want to continue? (yes/no): " response
    if [[ "$response" != "yes" ]]; then
        log "Deployment cancelled"
        exit 0
    fi
}

# Main execution
main() {
    log "AdhereLive Automated Build and Deployment"
    log "Environment: $ENVIRONMENT | Branch: $BRANCH"
    echo ""

    check_prerequisites
    prompt_confirmation
    
    cd "$SCRIPT_DIR"
    
    # Get project information from Terraform
    get_codebuild_projects
    get_ecs_info
    
    # Build both services
    log "Starting parallel builds..."
    
    # Start backend build in background
    (trigger_build "$BACKEND_PROJECT" "backend") &
    BACKEND_PID=$!
    
    # Start frontend build in background  
    (trigger_build "$FRONTEND_PROJECT" "frontend") &
    FRONTEND_PID=$!
    
    # Wait for both builds to complete
    log "Waiting for builds to complete..."
    wait $BACKEND_PID
    wait $FRONTEND_PID
    
    success "All builds completed successfully!"
    
    # Update ECS services
    log "Updating ECS services..."
    update_ecs_service "$BACKEND_SERVICE" "$ECS_CLUSTER"
    update_ecs_service "$FRONTEND_SERVICE" "$ECS_CLUSTER"
    
    # Verify deployment
    verify_deployment
    
    # Show final status
    show_status
    
    success "Deployment completed successfully!"
}

# Handle script interruption
trap 'error "Script interrupted"' INT TERM

# Run main function
main "$@"