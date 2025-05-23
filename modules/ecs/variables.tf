# modules/ecs/variables.tf
variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs of the public subnets"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "IDs of the private subnets"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "ID of the ALB security group"
  type        = string
}

variable "ecs_security_group_id" {
  description = "ID of the ECS security group"
  type        = string
}

variable "mysql_endpoint" {
  description = "MySQL endpoint"
  type        = string
}

variable "documentdb_endpoint" {
  description = "DocumentDB endpoint"
  type        = string
}

variable "backend_image" {
  description = "Backend Docker image"
  type        = string
}

variable "frontend_image" {
  description = "Frontend Docker image"
  type        = string
}

variable "backend_cpu" {
  description = "Backend CPU units"
  type        = number
  default     = 512
}

variable "backend_memory" {
  description = "Backend memory (MB)"
  type        = number
  default     = 1024
}

variable "frontend_cpu" {
  description = "Frontend CPU units"
  type        = number
  default     = 256
}

variable "frontend_memory" {
  description = "Frontend memory (MB)"
  type        = number
  default     = 512
}

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

variable "domain_name" {
  description = "Domain name"
  type        = string
}

variable "subdomain" {
  description = "Subdomain"
  type        = string
}

variable "mysql_database" {
  description = "MySQL database name"
  type        = string
}

variable "mysql_username" {
  description = "MySQL username"
  type        = string
}

variable "mysql_password" {
  description = "MySQL password"
  type        = string
  sensitive   = true
}

variable "mongodb_username" {
  description = "MongoDB username"
  type        = string
}

variable "mongodb_password" {
  description = "MongoDB password"
  type        = string
  sensitive   = true
}

variable "certificate_arn" {
  description = "ACM certificate ARN"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}