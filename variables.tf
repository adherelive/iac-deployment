variable "region" {
  description = "The AWS Region in which all resources should be created"
  default     = "us-east-1"
}

variable "secondary_region" {
  description = "The secondary AWS Region for disaster recovery"
  default     = "us-west-2"  # Different region for DR
}

variable "prefix" {
  description = "The prefix which should be used for all resources"
  default     = "al"
}

variable "ami_id" {
  description = "The AMI ID to use for EC2 instances in the primary region (Ubuntu 20.04 LTS)"
  default     = "ami-0aa2b7722dc1b5612" # Replace with a valid Ubuntu AMI for your region
}

variable "dr_ami_id" {
  description = "The AMI ID to use for DR EC2 instances (Ubuntu 20.04 LTS in secondary region)"
  default     = "ami-03d5c68bab01f3496" # Replace with a valid Ubuntu AMI for the secondary region
}

variable "dr_mode" {
  description = "Disaster recovery mode: active-passive or pilot-light"
  default     = "pilot-light"  # Options: active-passive, pilot-light
  
  validation {
    condition     = contains(["active-passive", "pilot-light"], var.dr_mode)
    error_message = "DR mode must be either 'active-passive' or 'pilot-light'."
  }
}

variable "admin_username" {
  description = "Username for the EC2 instances"
  default     = "ubuntu"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key for EC2 authentication"
  default     = "~/.ssh/id_rsa.pub"
}

variable "github_ssh_key_path" {
  description = "Path to the SSH private key for GitHub access"
  default     = "~/.ssh/github_key"
}

variable "admin_ip_address" {
  description = "The IP address that can be used to SSH to the EC2 instances (without /32 suffix)"
  default     = "0.0.0.0" # Ideally, restrict to your IP address
}

variable "mysql_admin_password" {
  description = "The password for the MySQL administrator account"
  sensitive   = true
}

variable "mongodb_admin_password" {
  description = "The password for the MongoDB administrator account"
  sensitive   = true
}

variable "domain_name" {
  description = "The domain name to use for the application"
  default     = "adherelive.com"
  
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]\\.[a-z]{2,}$", var.domain_name))
    error_message = "The domain name must be a valid domain with at least two labels (e.g., example.com)."
  }
}

variable "email" {
  description = "Email address for Let's Encrypt notifications"
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.email))
    error_message = "The email must be a valid email address format."
  }
}