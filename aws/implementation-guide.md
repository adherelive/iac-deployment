# AdhereLive AWS Infrastructure Implementation Guide

## Overview

This guide walks you through deploying your ReactJS + Node.js application on AWS using Terraform, following your logical and experimental learning approach. The infrastructure includes:

- **VPC** with public/private subnets across 2 AZs
- **Application Load Balancer** with HTTPS termination
- **ECS Fargate** for containerized applications
- **RDS MySQL** for relational data
- **DocumentDB** for MongoDB-compatible document storage
- **Route53** for DNS management
- **ACM** for SSL certificates

## Prerequisites

1. **AWS Account** with 'adherelive' user configured
2. **Domain 'adhere.live'** hosted in Route53
3. **Docker images** built and accessible (ECR or Docker Hub)
4. **Terraform** installed (v1.0+)
5. **AWS CLI** configured

## Phase 1: Setup and Permissions

### Step 1: Configure AWS Permissions
Follow the [AWS IAM Permissions Guide](#aws_permissions_guide) to set up the required permissions for the 'adherelive' user.

### Step 2: Prepare Your Environment
```bash
# Create project directory
mkdir adherelive-infrastructure
cd adherelive-infrastructure

# Create directory structure
mkdir -p modules/{vpc,security-groups,rds,documentdb,ecs,acm,route53}
```

### Step 3: Set Up Terraform Files
Copy all the Terraform configuration files into their respective directories:

```
adherelive-infrastructure/
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars (created by script)
├── deploy-infrastructure.sh
└── modules/
    ├── vpc/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── security-groups/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── rds/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── documentdb/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── ecs/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── acm/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── route53/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## Phase 2: Docker Image Preparation

### Step 4: Push Images to ECR (Recommended)
```bash
# Create ECR repositories
aws ecr create-repository --repository-name adherelive-be --region ap-south-1
aws ecr create-repository --repository-name adherelive-fe --region ap-south-1

# Get login token
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin <ACCOUNT-ID>.dkr.ecr.ap-south-1.amazonaws.com

# Tag and push your images
docker tag adherelive-be:prod <ACCOUNT-ID>.dkr.ecr.ap-south-1.amazonaws.com/adherelive-be:prod
docker tag adherelive-fe:prod <ACCOUNT-ID>.dkr.ecr.ap-south-1.amazonaws.com/adherelive-fe:prod

docker push <ACCOUNT-ID>.dkr.ecr.ap-south-1.amazonaws.com/adherelive-be:prod
docker push <ACCOUNT-ID>.dkr.ecr.ap-south-1.amazonaws.com/adherelive-fe:prod
```

## Phase 3: Experimental Deployment Approach

### Step 5: Initialize and Validate
```bash
# Make deployment script executable
chmod +x deploy-infrastructure.sh

# Initialize Terraform
./deploy-infrastructure.sh init
```

### Step 6: Plan Infrastructure (Experiment Phase)
```bash
# Generate and review plan
./deploy-infrastructure.sh plan

# Review the generated terraform.tfvars
# Update passwords, image URLs, and other configurations
```

### Step 7: Modular Testing Approach

For your logical learning preference, deploy in phases:

#### Phase 7a: Network Foundation
Test VPC and security groups first by commenting out other modules in `main.tf`:

```hcl
# Comment out in main.tf for testing
# module "rds" { ... }
# module "documentdb" { ... }
# module "ecs" { ... }
```

```bash
./deploy-infrastructure.sh apply
```

#### Phase 7b: Database Layer
Uncomment and test databases:

```bash
# Uncomment RDS and DocumentDB modules
./deploy-infrastructure.sh plan
./deploy-infrastructure.sh apply
```

#### Phase 7c: Application Layer
Finally, deploy the complete application:

```bash
# Uncomment all modules
./deploy-infrastructure.sh plan
./deploy-infrastructure.sh apply
```

## Phase 4: Configuration and Testing

### Step 8: Update terraform.tfvars
```hcl
# Example configuration
aws_region  = "ap-south-1"
environment = "prod"

domain_name = "adhere.live"
subdomain   = "test"

# Update with your ECR image URLs
backend_image  = "<ACCOUNT-ID>.dkr.ecr.ap-south-1.amazonaws.com/adherelive-be:prod"
frontend_image = "<ACCOUNT-ID>.dkr.ecr.ap-south-1.amazonaws.com/adherelive-fe:prod"

# Database passwords (use strong passwords!)
mysql_password   = "your-secure-mysql-password"
mongodb_password = "your-secure-mongodb-password"

# Scaling for 100 concurrent users
backend_desired_count  = 3
frontend_desired_count = 2
backend_cpu           = 512
backend_memory        = 1024
frontend_cpu          = 256
frontend_memory       = 512

# Production settings
enable_multi_az             = true  # For DR
backup_retention_period     = 30    # For compliance
enable_cross_region_backup  = true  # For DR
```

### Step 9: Deploy Complete Infrastructure
```bash
./deploy-infrastructure.sh apply
```

### Step 10: Verify Deployment
```bash
# Check outputs
terraform output

# Test the application
curl -I https://test.adhere.live

# Check ECS services
aws ecs list-services --cluster adherelive-prod-cluster

# Check database connectivity
aws rds describe-db-instances --db-instance-identifier adherelive-prod-mysql
```

## Phase 5: Disaster Recovery Setup

### Step 11: Enable Multi-AZ and Backups
Update `terraform.tfvars`:

```hcl
enable_multi_az             = true
backup_retention_period     = 30
enable_cross_region_backup  = true
```

### Step 12: Cross-Region Backup (Optional)
For complete DR, set up cross-region replication:

```bash
# Create read replica in another region
aws rds create-db-instance-read-replica \
    --db-instance-identifier adherelive-prod-mysql-replica-mumbai-dr \
    --source-db-instance-identifier adherelive-prod-mysql \
    --destination-region ap-southeast-1
```

## Phase 6: Monitoring and Optimization

### Step 13: Set Up CloudWatch Dashboards
```bash
# Create custom dashboard
aws cloudwatch put-dashboard \
    --dashboard-name "AdhereLive-Production" \
    --dashboard-body file://dashboard.json
```

### Step 14: Auto Scaling Configuration
The infrastructure includes auto-scaling based on CPU utilization (70% target). Monitor and adjust:

```bash
# Check auto-scaling activities
aws application-autoscaling describe-scaling-activities \
    --service-namespace ecs
```

## Troubleshooting Common Issues

### SSL Certificate Issues
- Ensure Route53 hosted zone exists for 'adhere.live'
- Check DNS propagation: `dig test.adhere.live`
- Verify certificate validation in ACM console

### ECS Task Failures
- Check CloudWatch logs: `/ecs/adherelive-prod-backend`
- Verify security group rules allow database connections
- Check environment variables in task definitions

### Database Connection Issues
- Verify security groups allow port 3306 (MySQL) and 27017 (DocumentDB)
- Check VPC endpoint configurations
- Validate connection strings and credentials

### Load Balancer Health Checks
- Ensure your application responds to health check paths
- Check target group health in AWS console
- Verify security group rules for ALB → ECS communication

## Cost Optimization Tips

1. **Use Spot Instances** for non-critical workloads
2. **Enable ECS Service Auto Scaling** based on metrics
3. **Use RDS Reserved Instances** for production
4. **Implement CloudWatch cost alerts**
5. **Schedule non-production resources** to shut down during off-hours

## Next Steps

1. **Set up CI/CD pipeline** using GitHub Actions or AWS CodePipeline
2. **Implement blue-green deployments** for zero-downtime updates
3. **Add WAF protection** for enhanced security
4. **Set up comprehensive monitoring** with custom metrics
5. **Create disaster recovery procedures** and test them regularly

## Cleanup

To destroy the infrastructure:

```bash
./deploy-infrastructure.sh destroy
```

**Warning**: This will permanently delete all resources including databases. Ensure you have backups!

## Support

For issues specific to this infrastructure:
1. Check CloudWatch logs for application errors
2. Review Terraform state for resource drift
3. Validate AWS permissions if deployment fails
4. Use AWS Support for service-specific issues

## Experimental Learning Extensions

Since you prefer logical approaches and experimentation, here are additional learning opportunities:

### Experiment 1: Load Testing
```bash
# Install and run load testing
npm install -g artillery
artillery quick --count 100 --num 10 https://test.adhere.live
```

### Experiment 2: Auto Scaling Behavior
```bash
# Trigger high CPU to test auto scaling
aws ecs update-service \
    --cluster adherelive-prod-cluster \
    --service adherelive-prod-backend \
    --desired-count 1

# Monitor scaling events
watch -n 30 'aws ecs describe-services --cluster adherelive-prod-cluster --services adherelive-prod-backend'
```

### Experiment 3: Disaster Recovery Simulation
```bash
# Simulate AZ failure by stopping tasks in one AZ
aws ecs list-tasks --cluster adherelive-prod-cluster --service-name adherelive-prod-backend
aws ecs stop-task --cluster adherelive-prod-cluster --task <task-arn>
```

### Experiment 4: Database Performance Tuning
```bash
# Monitor database performance
aws rds describe-db-log-files --db-instance-identifier adherelive-prod-mysql
aws logs get-log-events --log-group-name /aws/rds/instance/adherelive-prod-mysql/slowquery
```

This infrastructure provides a solid foundation for your 100-user application with room to scale and experiment as you learn more about AWS services.