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
  description = "URL of the application"
  value       = "https://${var.subdomain}.${var.domain_name}"
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

# Certificate Output
output "certificate_arn" {
  description = "ARN of the SSL certificate"
  value       = module.acm.certificate_arn
}

# Route53 Outputs
output "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  value       = module.route53.hosted_zone_id
}

output "dns_name" {
  description = "DNS name for the application"
  value       = "${var.subdomain}.${var.domain_name}"
}