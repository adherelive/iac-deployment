# modules/codebuild/variables.tf
variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "backend_repo_url" {
  description = "Backend repository URL"
  type        = string
}

variable "frontend_repo_url" {
  description = "Frontend repository URL"
  type        = string
}

variable "backend_branch" {
  description = "Backend repository branch"
  type        = string
  default     = "main"
}

variable "frontend_branch" {
  description = "Frontend repository branch"
  type        = string
  default     = "main"
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}