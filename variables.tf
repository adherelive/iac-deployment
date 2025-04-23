variable "region" {
  description = "The AWS Region in which all resources should be created"
  default     = "us-east-1"
}

variable "prefix" {
  description = "The prefix which should be used for all resources"
  default     = "al"
}

variable "ami_id" {
  description = "The AMI ID to use for EC2 instances (Ubuntu 20.04 LTS)"
  default     = "ami-0c55b159cbfafe1f0" # Replace with a valid Ubuntu AMI for your region
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
}

variable "email" {
  description = "Email address for Let's Encrypt notifications"
}