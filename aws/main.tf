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
  image_tag      = var.image_tag
  
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

# --- AWS Secrets Manager ---
resource "aws_secretsmanager_secret" "app_secrets" {
  name = "${local.name_prefix}-${local.environment}-app-secrets"
  
  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "app_secrets_initial_version" {
  secret_id = aws_secretsmanager_secret.app_secrets.id
  secret_string = jsonencode({
    # This is a placeholder. The actual secrets will be populated manually
    # or by a CI/CD pipeline.
    # The keys here should match the environment variable names in your app.
    MONGO_DB_URI = "mongodb+srv://user:password@your-atlas-cluster"
    # Add other backend secrets from your .env file here
    GETSTREAM_API_KEY = "dummy-key"
    GETSTREAM_API_SECRET = "dummy-secret"
  })
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
  
  # Application configuration
  backend_image    = "${module.codebuild.backend_ecr_repository_url}:${var.image_tag}"
  frontend_image   = "${module.codebuild.frontend_ecr_repository_url}:${var.image_tag}"
  domain_name      = var.domain_name
  subdomain        = var.subdomain
  
  # Environment variables for MySQL (passed directly for simplicity here)
  # In a production setup, these should also be in Secrets Manager.
  mysql_database   = var.mysql_database
  mysql_username   = var.mysql_username
  mysql_password   = var.mysql_password

  # Secrets from Secrets Manager
  app_secrets_manager_arn = aws_secretsmanager_secret.app_secrets.arn
  
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
