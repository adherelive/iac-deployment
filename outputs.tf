########################
# Outputs
########################
output "frontend_public_ip" {
  value = aws_eip.frontend_eip.public_ip
}

output "backend_public_ip" {
  value = aws_eip.backend_eip.public_ip
}

output "cloudfront_frontend_domain" {
  value = aws_cloudfront_distribution.frontend.domain_name
}

output "cloudfront_backend_domain" {
  value = aws_cloudfront_distribution.backend.domain_name
}

output "mysql_endpoint" {
  value = aws_db_instance.mysql.endpoint
}

output "mongodb_endpoint" {
  value = aws_docdb_cluster.mongodb.endpoint
}

output "mongodb_username" {
  value = aws_docdb_cluster.mongodb.master_username
}

output "mongodb_password" {
  value     = var.mongodb_admin_password
  sensitive = true
}

output "redis_endpoint" {
  value = aws_elasticache_cluster.redis.cache_nodes.0.address
}

output "redis_port" {
  value = aws_elasticache_cluster.redis.cache_nodes.0.port
}

output "route53_nameservers" {
  value = aws_route53_zone.main.name_servers
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.sessions.name
}

output "s3_static_assets_bucket" {
  value = aws_s3_bucket.static_assets.bucket
}

output "dr_status" {
  value = "DR environment is configured in ${var.dr_mode} mode in ${var.secondary_region}"
}

output "dr_frontend_public_ip" {
  value = var.dr_mode == "active-passive" ? aws_eip.dr_frontend_eip[0].public_ip : "Not deployed in pilot-light mode"
}

output "dr_backend_public_ip" {
  value = var.dr_mode == "active-passive" ? aws_eip.dr_backend_eip[0].public_ip : "Not deployed in pilot-light mode"
}