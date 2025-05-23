# modules/acm/variables.tf
variable "domain_name" {
  description = "Domain name for the certificate"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# modules/acm/outputs.tf
output "certificate_arn" {
  description = "ARN of the certificate"
  value       = aws_acm_certificate_validation.main.certificate_arn
}