# Create a DR EC2 instances for active-passive mode
resource "aws_instance" "dr_backend" {
  provider                    = aws.dr_region
  count                       = var.dr_mode == "active-passive" ? 1 : 0
  ami                         = var.dr_ami_id
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.dr_public_subnet_a.id
  vpc_security_group_ids      = [aws_security_group.dr_backend_sg.id]
  key_name                    = aws_key_pair.dr_ssh_key.key_name

  user_data = templatefile("${path.module}/scripts/backend_init.sh", {
    mysql_host       = var.dr_mode == "active-passive" ? aws_db_instance.dr_mysql_full[0].address : aws_db_instance.dr_mysql[0].address
    mysql_user       = "mysqladmin"
    mysql_password   = var.mysql_admin_password
    mysql_database   = "adhere"
    mongodb_host     = var.dr_mode == "active-passive" ? aws_docdb_cluster.dr_mongodb[0].endpoint : aws_docdb_cluster.dr_mongodb_pilot[0].endpoint
    mongodb_username = "docdbadmin"
    mongodb_password = var.mongodb_admin_password
    redis_host       = var.dr_mode == "active-passive" ? aws_elasticache_cluster.dr_redis[0].cache_nodes.0.address : ""
    redis_port       = "6379"
    redis_password   = ""
    admin_username   = var.admin_username
    domain_name      = var.domain_name
  })

  tags = {
    Name = "${var.prefix}-dr-backend"
  }
}

resource "aws_instance" "dr_frontend" {
  provider                    = aws.dr_region
  count                       = var.dr_mode == "active-passive" ? 1 : 0
  ami                         = var.dr_ami_id
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.dr_public_subnet_a.id
  vpc_security_group_ids      = [aws_security_group.dr_frontend_sg.id]
  key_name                    = aws_key_pair.dr_ssh_key.key_name

  user_data = templatefile("${path.module}/scripts/frontend_init.sh", {
    backend_url    = var.dr_mode == "active-passive" ? "http://${aws_instance.dr_backend[0].private_ip}:5000" : ""
    domain_name    = var.domain_name
    email          = var.email
    admin_username = var.admin_username
  })

  tags = {
    Name = "${var.prefix}-dr-frontend"
  }
}

# Allocate Elastic IPs for DR instances (if active-passive)
resource "aws_eip" "dr_frontend_eip" {
  provider = aws.dr_region
  count    = var.dr_mode == "active-passive" ? 1 : 0
  instance = aws_instance.dr_frontend[0].id
  
  tags = {
    Name = "${var.prefix}-dr-frontend-eip"
  }
}

resource "aws_eip" "dr_backend_eip" {
  provider = aws.dr_region
  count    = var.dr_mode == "active-passive" ? 1 : 0
  instance = aws_instance.dr_backend[0].id
  
  tags = {
    Name = "${var.prefix}-dr-backend-eip"
  }
}

# Add Route53 failover DNS records for the frontend
resource "aws_route53_health_check" "dr_frontend_health" {
  count             = var.dr_mode == "active-passive" ? 1 : 0
  fqdn              = aws_eip.dr_frontend_eip[0].public_dns
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30

  tags = {
    Name = "${var.prefix}-dr-frontend-health"
  }
}

# Create failover DNS records
resource "aws_route53_record" "frontend_failover_primary" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "failover.${var.domain_name}"
  type    = "A"
  
  failover_routing_policy {
    type = "PRIMARY"
  }
  
  set_identifier = "primary"
  health_check_id = aws_route53_health_check.frontend_health.id

  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "frontend_failover_secondary" {
  count   = var.dr_mode == "active-passive" ? 1 : 0
  zone_id = aws_route53_zone.main.zone_id
  name    = "failover.${var.domain_name}"
  type    = "A"
  
  failover_routing_policy {
    type = "SECONDARY"
  }
  
  set_identifier = "secondary"
  health_check_id = aws_route53_health_check.dr_frontend_health[0].id

  ttl     = 300
  records = [aws_eip.dr_frontend_eip[0].public_ip]
}

# Add database backup/snapshot replication policies
resource "aws_db_instance_automated_backups_replication" "mysql_backup_replication" {
  provider               = aws.dr_region
  source_db_instance_arn = aws_db_instance.mysql.arn
  retention_period       = 7
}