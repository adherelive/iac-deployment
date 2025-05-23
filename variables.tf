# variables.tf - Terraform Variables

# General Configuration
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-south-1"
}

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "default"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

# Network Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# Domain Configuration
variable "domain_name" {
  description = "Root domain name"
  type        = string
  default     = "adhere.live"
}

variable "subdomain" {
  description = "Subdomain for the application"
  type        = string
  default     = "test"
}

# SSL Configuration
variable "enable_ssl" {
  description = "Enable SSL certificate and HTTPS"
  type        = bool
  default     = false
}

variable "ssl_certificate_arn" {
  description = "ARN of existing SSL certificate (optional)"
  type        = string
  default     = ""
}

# GitHub Repository Configuration
variable "backend_repo_url" {
  description = "GitHub repository URL for backend"
  type        = string
  default     = "https://github.com/adherelive/adherelive-web.git"
}

variable "frontend_repo_url" {
  description = "GitHub repository URL for frontend"
  type        = string
  default     = "https://github.com/adherelive/adherelive-fe.git"
}

variable "backend_branch" {
  description = "Git branch for backend repository"
  type        = string
  default     = "akshay-gaurav-latest-changes"
}

variable "frontend_branch" {
  description = "Git branch for frontend repository"
  type        = string
  default     = "akshay-gaurav-latest-changes"
}

variable "image_tag" {
  description = "Docker image tag for builds"
  type        = string
  default     = "latest"
}

# Application Configuration
variable "backend_image" {
  description = "Docker image for backend service (auto-generated from CodeBuild)"
  type        = string
  default     = ""
}

variable "frontend_image" {
  description = "Docker image for frontend service (auto-generated from CodeBuild)"
  type        = string
  default     = ""
}

# Database Configuration - MySQL
variable "mysql_database" {
  description = "MySQL database name"
  type        = string
  default     = "adhere"
}

variable "mysql_username" {
  description = "MySQL master username"
  type        = string
  default     = "user"
}

variable "mysql_password" {
  description = "MySQL master password"
  type        = string
  sensitive   = true
}

# Database Configuration - MongoDB (DocumentDB)
variable "mongodb_username" {
  description = "MongoDB master username"
  type        = string
  default     = "mongouser"
}

variable "mongodb_password" {
  description = "MongoDB master password"
  type        = string
  sensitive   = true
}

# Scaling Configuration
variable "backend_desired_count" {
  description = "Desired number of backend tasks"
  type        = number
  default     = 2
}

variable "frontend_desired_count" {
  description = "Desired number of frontend tasks"
  type        = number
  default     = 2
}

variable "backend_cpu" {
  description = "CPU units for backend tasks"
  type        = number
  default     = 512
}

variable "backend_memory" {
  description = "Memory (MB) for backend tasks"
  type        = number
  default     = 1024
}

variable "frontend_cpu" {
  description = "CPU units for frontend tasks"
  type        = number
  default     = 256
}

variable "frontend_memory" {
  description = "Memory (MB) for frontend tasks"
  type        = number
  default     = 512
}

# RDS Configuration
variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "rds_max_allocated_storage" {
  description = "RDS maximum allocated storage in GB"
  type        = number
  default     = 100
}

# DocumentDB Configuration
variable "documentdb_instance_class" {
  description = "DocumentDB instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "documentdb_cluster_size" {
  description = "Number of DocumentDB instances"
  type        = number
  default     = 1
}

# Auto Scaling Configuration
variable "enable_auto_scaling" {
  description = "Enable ECS auto scaling"
  type        = bool
  default     = true
}

variable "auto_scaling_min_capacity" {
  description = "Minimum capacity for auto scaling"
  type        = number
  default     = 1
}

variable "auto_scaling_max_capacity" {
  description = "Maximum capacity for auto scaling"
  type        = number
  default     = 10
}

variable "auto_scaling_target_cpu" {
  description = "Target CPU utilization for auto scaling"
  type        = number
  default     = 70
}

# Disaster Recovery Configuration
variable "enable_multi_az" {
  description = "Enable Multi-AZ deployment for databases"
  type        = bool
  default     = false # Set to true for production DR
}

variable "backup_retention_period" {
  description = "Database backup retention period in days"
  type        = number
  default     = 7
}

variable "enable_cross_region_backup" {
  description = "Enable cross-region backup replication"
  type        = bool
  default     = false # Enable for DR
}