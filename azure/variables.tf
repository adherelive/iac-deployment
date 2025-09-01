# variables.tf

variable "location" {
  description = "The Azure region to deploy the resources in."
  type        = string
  default     = "East US"
}

variable "environment" {
  description = "The deployment environment (e.g., dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "resource_group_name" {
  description = "The name of the resource group."
  type        = string
}

variable "key_vault_name" {
  description = "The name of the Azure Key Vault."
  type        = string
}

variable "ssh_public_key" {
  description = "The public SSH key to be used for accessing the VMs."
  type        = string
  sensitive   = true
}

variable "my_ip_address" {
  description = "Your public IP address. Used to restrict SSH access to the VMs."
  type        = string
}

variable "vm_size" {
  description = "The size of the virtual machines."
  type        = string
  default     = "Standard_B2s"
}

variable "github_repo_fe" {
  description = "The URL of the frontend GitHub repository."
  type        = string
}

variable "github_repo_be" {
  description = "The URL of the backend GitHub repository."
  type        = string
}

variable "mysql_server_name" {
  description = "The name of the MySQL server."
  type        = string
  default     = "adherelive-mysql-server"
}

variable "mysql_admin_username" {
  description = "The admin username for the MySQL server."
  type        = string
  default     = "mysqladmin"
}

variable "mysql_admin_password" {
  description = "The admin password for the MySQL server."
  type        = string
  sensitive   = true
}

variable "mysql_sku_name" {
  description = "The SKU name for the MySQL server."
  type        = string
  default     = "B_Gen5_1"
}

variable "redis_cache_name" {
  description = "The name of the Redis cache."
  type        = string
  default     = "adherelive-redis-cache"
}

variable "redis_sku_name" {
  description = "The SKU name for the Redis cache."
  type        = string
  default     = "Basic"
}

variable "redis_family" {
    description = "The family for the Redis cache."
    type        = string
    default     = "C"
}

variable "redis_capacity" {
    description = "The capacity for the Redis cache."
    type        = number
    default     = 0
}
