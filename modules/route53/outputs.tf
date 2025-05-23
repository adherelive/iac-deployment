# modules/route53/outputs.tf
output "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  value       = data.aws_route53_zone.main.zone_id
}

output "record_name" {
  description = "Route53 record name"
  value       = aws_route53_record.main.name
}