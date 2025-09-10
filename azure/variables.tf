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
  default     = "adherelive-rg"
}

variable "key_vault_name" {
  description = "The name of the Azure Key Vault. Must be globally unique."
  type        = string
  default     = "adherelive-kv-12345"
}

variable "acr_name" {
  description = "The name of the Azure Container Registry. Must be globally unique."
  type        = string
  default     = "adhereliveacr12345"
}

variable "frontend_image_name" {
  description = "The name of the frontend image in ACR."
  type        = string
  default     = "adherelive-fe"
}

variable "backend_image_name" {
  description = "The name of the backend image in ACR."
  type        = string
  default     = "adherelive-be"
}

variable "image_tag" {
  description = "The tag of the Docker images to deploy."
  type        = string
  default     = "latest"
}

variable "mysql_server_name" {
  description = "The name of the MySQL flexible server."
  type        = string
  default     = "adherelive-mysql-server"
}

variable "mysql_admin_username" {
  description = "The admin username for the MySQL server."
  type        = string
}

variable "mysql_admin_password" {
  description = "The admin password for the MySQL server."
  type        = string
  sensitive   = true
}

variable "mysql_sku_name" {
  description = "The SKU name for the MySQL server. Example: GP_Standard_D2ds_v4"
  type        = string
  default     = "GP_Standard_D2ds_v4"
}
