variable "prefix" {
  description = "The prefix which should be used for all resources"
  default     = "alprod"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,50}[a-z0-9]$", var.prefix)) || can(regex("^[a-z][a-z0-9]$", var.prefix))
    error_message = "The prefix must start with a letter, end with a letter or number, and contain only lowercase letters, numbers, and hyphens. Maximum length is 50 characters."
  }
}

variable "location" {
  description = "The Azure Region in which all resources should be created"
  default     = "Central India"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  default     = "adherelive-prod"
}

variable "admin_username" {
  description = "Username for the Virtual Machine"
  default     = "adherelive"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key for Azure VM authentication & GitHub"
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
  default     = "adherelivedemo"
}

variable "email" {
  description = "Email address for Let's Encrypt notifications"
  default	  = "gagneet.singh@adhere.live"
}

