# modules/route53/variables.tf
variable "domain_name" {
  description = "Domain name"
  type        = string
}

variable "subdomain" {
  description = "Subdomain"
  type        = string
}

variable "alb_dns_name" {
  description = "ALB DNS name"
  type        = string
}

variable "alb_zone_id" {
  description = "ALB zone ID"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
}