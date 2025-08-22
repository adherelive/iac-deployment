#!/bin/bash
# comprehensive-fix.sh - Fix all Terraform validation errors

echo "Applying comprehensive fix for Terraform validation errors..."

# Fix 1: Add missing variable to variables.tf
echo "Adding missing mongodb_database variable..."

cat >> variables.tf << 'EOF'

# MongoDB Database Configuration
variable "mongodb_database" {
  description = "MongoDB database name"
  type        = string
  default     = "adhere"
}
EOF

# Fix 2: Update main.tf to comment out ACM and Route53 modules initially
echo "Updating main.tf to comment out SSL modules..."

cat > main_fixed.tf << 'EOF'
# main.tf - Root Terraform Configuration for AdhereLive Application

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile # Optional: use if you have AWS CLI profiles
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# Local values for consistent naming
locals {
  name_prefix = "adherelive"
  environment = var.environment
  
  common_tags = {
    Project     = "AdhereLive"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = "adherelive"
  }
}

# CodeBuild Module for GitHub Integration
module "codebuild" {
  source = "./modules/codebuild"
  
  name_prefix    = local.name_prefix
  environment    = local.environment
  aws_region     = var.aws_region
  
  # Repository Configuration
  backend_repo_url   = var.backend_repo_url
  frontend_repo_url  = var.frontend_repo_url
  backend_branch     = var.backend_branch
  frontend_branch    = var.frontend_branch
  image_tag          = var.image_tag
  
  tags = local.common_tags
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"
  
  name_prefix         = local.name_prefix
  environment        = local.environment
  cidr_block         = var.vpc_cidr
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
  
  tags = local.common_tags
}

# Security Groups Module
module "security_groups" {
  source = "./modules/security-groups"
  
  name_prefix = local.name_prefix
  environment = local.environment
  vpc_id      = module.vpc.vpc_id
  
  tags = local.common_tags
}

# RDS Module (MySQL)
module "rds" {
  source = "./modules/rds"
  
  name_prefix           = local.name_prefix
  environment          = local.environment
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  security_group_ids   = [module.security_groups.rds_security_group_id]
  
  db_name     = var.mysql_database
  db_username = var.mysql_username
  db_password = var.mysql_password
  
  tags = local.common_tags
}

# DocumentDB Module (MongoDB replacement)
module "documentdb" {
  source = "./modules/documentdb"
  
  name_prefix           = local.name_prefix
  environment          = local.environment
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  security_group_ids   = [module.security_groups.documentdb_security_group_id]
  
  master_username  = var.mongodb_username
  master_password  = var.mongodb_password
  mongodb_database = var.mongodb_database
  
  tags = local.common_tags
}

# ECS Cluster Module
module "ecs" {
  source = "./modules/ecs"
  
  name_prefix           = local.name_prefix
  environment          = local.environment
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  public_subnet_ids    = module.vpc.public_subnet_ids
  
  # Security Groups
  alb_security_group_id = module.security_groups.alb_security_group_id
  ecs_security_group_id = module.security_groups.ecs_security_group_id
  
  # Database connections
  mysql_endpoint    = module.rds.endpoint
  documentdb_endpoint = module.documentdb.endpoint
  
  # Application configuration
  backend_image    = "${module.codebuild.backend_ecr_repository_url}:${var.image_tag}"
  frontend_image   = "${module.codebuild.frontend_ecr_repository_url}:${var.image_tag}"
  domain_name      = var.domain_name
  subdomain        = var.subdomain
  
  # Environment variables
  mysql_database   = var.mysql_database
  mysql_username   = var.mysql_username
  mysql_password   = var.mysql_password
  mongodb_username = var.mongodb_username
  mongodb_password = var.mongodb_password
  
  # SSL Certificate (empty for now)
  certificate_arn = ""
  
  tags = local.common_tags
}

# ACM Certificate Module (commented out initially for domain setup)
# Uncomment after DNS is configured
# module "acm" {
#   source = "./modules/acm"
#   
#   domain_name = "${var.subdomain}.${var.domain_name}"
#   
#   tags = local.common_tags
# }

# Route53 Module (commented out initially for domain setup)  
# Uncomment after DNS is configured
# module "route53" {
#   source = "./modules/route53"
#   
#   domain_name       = var.domain_name
#   subdomain         = var.subdomain
#   alb_dns_name      = module.ecs.alb_dns_name
#   alb_zone_id       = module.ecs.alb_zone_id
#   certificate_arn   = module.acm.certificate_arn
#   
#   tags = local.common_tags
# }
EOF

# Backup original and replace
cp main.tf main.tf.backup
mv main_fixed.tf main.tf

# Fix 3: Update outputs.tf to comment out SSL-related outputs
echo "Updating outputs.tf..."

cat > outputs_fixed.tf << 'EOF'
# outputs.tf - Terraform Outputs

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "database_subnet_ids" {
  description = "IDs of the database subnets"
  value       = module.vpc.database_subnet_ids
}

# CodeBuild Outputs
output "backend_ecr_repository_url" {
  description = "Backend ECR repository URL"
  value       = module.codebuild.backend_ecr_repository_url
}

output "frontend_ecr_repository_url" {
  description = "Frontend ECR repository URL"
  value       = module.codebuild.frontend_ecr_repository_url
}

output "backend_codebuild_project_name" {
  description = "Backend CodeBuild project name"
  value       = module.codebuild.backend_codebuild_project_name
}

output "frontend_codebuild_project_name" {
  description = "Frontend CodeBuild project name"
  value       = module.codebuild.frontend_codebuild_project_name
}

# Load Balancer Outputs
output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = module.ecs.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the load balancer"
  value       = module.ecs.alb_zone_id
}

output "application_url" {
  description = "URL of the application (HTTP for now)"
  value       = "http://${module.ecs.alb_dns_name}"
}

# ECS Outputs
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "backend_service_name" {
  description = "Name of the backend ECS service"
  value       = module.ecs.backend_service_name
}

output "frontend_service_name" {
  description = "Name of the frontend ECS service"
  value       = module.ecs.frontend_service_name
}

# Database Outputs
output "mysql_endpoint" {
  description = "RDS MySQL endpoint"
  value       = module.rds.endpoint
}

output "mysql_port" {
  description = "RDS MySQL port"
  value       = module.rds.port
}

output "documentdb_endpoint" {
  description = "DocumentDB cluster endpoint"
  value       = module.documentdb.endpoint
}

output "documentdb_port" {
  description = "DocumentDB port"
  value       = module.documentdb.port
}

# Security Group Outputs
output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = module.security_groups.alb_security_group_id
}

output "ecs_security_group_id" {
  description = "ID of the ECS security group"
  value       = module.security_groups.ecs_security_group_id
}

output "rds_security_group_id" {
  description = "ID of the RDS security group"
  value       = module.security_groups.rds_security_group_id
}

output "documentdb_security_group_id" {
  description = "ID of the DocumentDB security group"
  value       = module.security_groups.documentdb_security_group_id
}

# Commented out until SSL is enabled
# Certificate Output
# output "certificate_arn" {
#   description = "ARN of the SSL certificate"
#   value       = module.acm.certificate_arn
# }

# Route53 Outputs
# output "hosted_zone_id" {
#   description = "Route53 hosted zone ID"
#   value       = module.route53.hosted_zone_id
# }

# output "dns_name" {
#   description = "DNS name for the application"
#   value       = "${var.subdomain}.${var.domain_name}"
# }
EOF

# Backup original and replace
cp outputs.tf outputs.tf.backup
mv outputs_fixed.tf outputs.tf

echo "Main configuration files updated. Now fixing module files..."

# Fix 4: Update DocumentDB module to remove unsupported arguments
echo "Fixing DocumentDB module..."

cat > modules/documentdb/main_fixed.tf << 'EOF'
# modules/documentdb/main.tf - DocumentDB Module

# DocumentDB Subnet Group
resource "aws_docdb_subnet_group" "main" {
  name       = "${var.name_prefix}-${var.environment}-docdb-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.environment}-docdb-subnet-group"
  })
}

# DocumentDB Cluster Parameter Group
resource "aws_docdb_cluster_parameter_group" "main" {
  family = "docdb5.0"
  name   = "${var.name_prefix}-${var.environment}-docdb-params"

  parameter {
    name  = "tls"
    value = "enabled"
  }

  parameter {
    name  = "ttl_monitor"
    value = "enabled"
  }

  tags = var.tags
}

# DocumentDB Cluster
resource "aws_docdb_cluster" "main" {
  cluster_identifier      = "${var.name_prefix}-${var.environment}-docdb"
  engine                 = "docdb"
  engine_version         = "5.0.0"
  
  # Master credentials
  master_username = var.master_username
  master_password = var.master_password
  port           = 27017

  # Network configuration
  db_subnet_group_name   = aws_docdb_subnet_group.main.name
  vpc_security_group_ids = var.security_group_ids

  # Backup configuration
  backup_retention_period = var.backup_retention_period
  preferred_backup_window = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"

  # Parameter group
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.main.name

  # Encryption
  storage_encrypted = true

  # Deletion configuration
  deletion_protection     = false # Set to true for production
  skip_final_snapshot    = true   # Set to false for production
  final_snapshot_identifier = "${var.name_prefix}-${var.environment}-docdb-final-snapshot"

  # Enable CloudWatch logs
  enabled_cloudwatch_logs_exports = ["audit", "profiler"]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.environment}-docdb"
  })
}

# DocumentDB Cluster Instances (simplified)
resource "aws_docdb_cluster_instance" "cluster_instances" {
  count              = var.cluster_size
  identifier         = "${var.name_prefix}-${var.environment}-docdb-${count.index}"
  cluster_identifier = aws_docdb_cluster.main.id
  instance_class     = var.instance_class

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.environment}-docdb-${count.index}"
  })
}

# CloudWatch Alarms for DocumentDB
resource "aws_cloudwatch_metric_alarm" "documentdb_cpu" {
  count               = var.cluster_size
  alarm_name          = "${var.name_prefix}-${var.environment}-docdb-cpu-${count.index}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/DocDB"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors DocumentDB CPU utilization"
  
  dimensions = {
    DBInstanceIdentifier = aws_docdb_cluster_instance.cluster_instances[count.index].identifier
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "documentdb_connections" {
  alarm_name          = "${var.name_prefix}-${var.environment}-docdb-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/DocDB"
  period              = "120"
  statistic           = "Average"
  threshold           = "50"
  alarm_description   = "This metric monitors DocumentDB connection count"
  
  dimensions = {
    DBClusterIdentifier = aws_docdb_cluster.main.cluster_identifier
  }

  tags = var.tags
}
EOF

# Replace DocumentDB main.tf
cp modules/documentdb/main.tf modules/documentdb/main.tf.backup 2>/dev/null || true
mv modules/documentdb/main_fixed.tf modules/documentdb/main.tf

echo "All fixes applied!"
echo ""
echo "Summary of changes:"
echo "1. Added mongodb_database variable to variables.tf"
echo "2. Updated main.tf to comment out ACM and Route53 modules"
echo "3. Updated outputs.tf to comment out SSL-related outputs"
echo "4. Fixed DocumentDB module to remove unsupported arguments"
echo "5. Created backups of original files"
echo ""
echo "Now run: terraform validate"