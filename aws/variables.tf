# variables.tf for AWS root module

variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "ap-south-1"
}

variable "aws_profile" {
  description = "The AWS CLI profile to use for authentication. Optional."
  type        = string
  default     = null
}

variable "environment" {
  description = "The deployment environment (e.g., dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "mysql_database" {
  description = "The name of the MySQL database."
  type        = string
  default     = "adherelive"
}

variable "mysql_username" {
  description = "The username for the MySQL database."
  type        = string
}

variable "mysql_password" {
  description = "The password for the MySQL database."
  type        = string
  sensitive   = true
}

variable "image_tag" {
  description = "The Docker image tag to use. The pipeline will override this with the commit ID."
  type        = string
  default     = "latest"
}

variable "domain_name" {
  description = "The root domain name for the application (e.g., 'adhere.live')."
  type        = string
}

variable "subdomain" {
  description = "The subdomain for the application (e.g., 'portal')."
  type        = string
  default     = "portal"
}

# --- CI/CD Pipeline Variables ---

variable "github_owner" {
  description = "The owner (organization or user) of the GitHub repository."
  type        = string
}

variable "github_repo" {
  description = "The name of the GitHub repository."
  type        = string
}

variable "github_branch" {
  description = "The branch to trigger the pipeline from."
  type        = string
  default     = "main"
}

variable "codestar_connection_arn" {
  description = "The ARN of the AWS CodeStar connection to GitHub."
  type        = string
}
