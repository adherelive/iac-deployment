# modules/acm/outputs.tf
output "certificate_arn" {
  description = "ARN of the certificate"
  value       = aws_acm_certificate_validation.main.certificate_arn
}