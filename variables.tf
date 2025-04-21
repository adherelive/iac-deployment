variable "prefix" {
  description = "The prefix which should be used for all resources"
  default     = "adherelive"
}

variable "location" {
  description = "The Azure Region in which all resources should be created"
  default     = "East US"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  default     = "adherelive-rg"
}

variable "admin_username" {
  description = "Username for the Virtual Machine"
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key"
  default     = "~/.ssh/id_rsa.pub"
}

variable "admin_ip_address" {
  description = "The IP address range that can be used to SSH to the Virtual Machines"
  default     = "*"
}

variable "mysql_admin_password" {
  description = "The password for the MySQL administrator account"
  sensitive   = true
}

variable "domain_name" {
  description = "The domain name to use for the application"
  default     = "adherelive.com"
}

variable "email" {
  description = "Email address for Let's Encrypt notifications"
}