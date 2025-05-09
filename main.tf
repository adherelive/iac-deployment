# Create CloudFront distribution for frontend
resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.prefix}-frontend-distribution"
  default_root_object = "index.html"
  aliases             = [var.domain_name, "www.${var.domain_name}"]
  
  # Use the frontend EC2 instance as origin
  origin {
    domain_name = aws_instance.frontend.public_dns
    origin_id   = "frontend-origin"
    
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"  # Assuming EC2 is HTTP only; can be "https-only" if configured
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  
  # Default cache behavior
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "frontend-origin"
    
    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }
    
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
  
  # API endpoint cache behavior
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "frontend-origin"
    
    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Origin", "Host"]
      cookies {
        forward = "all"
      }
    }
    
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }
  
  # SSL certificate
  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
  
  # Geo restrictions
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  
  # Additional settings
  web_acl_id          = aws_wafv2_web_acl.main.arn
  wait_for_deployment = false
  
  tags = {
    Name = "${var.prefix}-cloudfront"
  }
}

# Create CloudFront WAF
resource "aws_wafv2_web_acl" "main" {
  name        = "${var.prefix}-waf-acl"
  description = "WAF ACL for AdhereLive application"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # AWS Managed Rules
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 0

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # SQL Injection Protection
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesSQLiRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "MainWafAclMetric"
    sampled_requests_enabled   = true
  }
}

# Create ACM Certificate for CloudFront (must be in us-east-1)
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

resource "aws_acm_certificate" "cert" {
  provider                  = aws.us-east-1
  domain_name               = var.domain_name
  subject_alternative_names = ["www.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# DNS validation records for ACM
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id
}

# Certificate validation
resource "aws_acm_certificate_validation" "cert" {
  provider                = aws.us-east-1
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

provider "aws" {
  region = var.region
}

resource "random_string" "unique_suffix" {
  length  = 6
  special = false
  upper   = false
}

# Create a VPC
resource "aws_vpc" "adherelive_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.prefix}-vpc"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.adherelive_vpc.id

  tags = {
    Name = "${var.prefix}-igw"
  }
}

# Create subnets
resource "aws_subnet" "public_subnet_a" {
  vpc_id                  = aws_vpc.adherelive_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}a"

  tags = {
    Name = "${var.prefix}-public-subnet-a"
  }
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id                  = aws_vpc.adherelive_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}b"

  tags = {
    Name = "${var.prefix}-public-subnet-b"
  }
}

resource "aws_subnet" "private_subnet_a" {
  vpc_id                  = aws_vpc.adherelive_vpc.id
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "${var.region}a"

  tags = {
    Name = "${var.prefix}-private-subnet-a"
  }
}

resource "aws_subnet" "private_subnet_b" {
  vpc_id                  = aws_vpc.adherelive_vpc.id
  cidr_block              = "10.0.4.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "${var.region}b"

  tags = {
    Name = "${var.prefix}-private-subnet-b"
  }
}

# Create route tables
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.adherelive_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.prefix}-public-rt"
  }
}

# Associate route table with public subnets
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.public_rt.id
}

# Create NAT Gateway
resource "aws_eip" "nat_eip" {
  tags = {
    Name = "${var.prefix}-nat-eip"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_a.id

  tags = {
    Name = "${var.prefix}-nat-gw"
  }
}

# Create private route table with NAT Gateway
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.adherelive_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "${var.prefix}-private-rt"
  }
}

# Associate route table with private subnets
resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_subnet_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_subnet_b.id
  route_table_id = aws_route_table.private_rt.id
}

# Create security groups
resource "aws_security_group" "frontend_sg" {
  name        = "${var.prefix}-frontend-sg"
  description = "Security group for frontend server"
  vpc_id      = aws_vpc.adherelive_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.admin_ip_address}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.prefix}-frontend-sg"
  }
}

resource "aws_security_group" "backend_sg" {
  name        = "${var.prefix}-backend-sg"
  description = "Security group for backend server"
  vpc_id      = aws_vpc.adherelive_vpc.id

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.admin_ip_address}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.prefix}-backend-sg"
  }
}

resource "aws_security_group" "db_sg" {
  name        = "${var.prefix}-db-sg"
  description = "Security group for databases"
  vpc_id      = aws_vpc.adherelive_vpc.id

  # MySQL
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_sg.id]
  }

  # MongoDB
  ingress {
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_sg.id]
  }

  # Redis
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.prefix}-db-sg"
  }
}

# Create key pair for SSH
resource "aws_key_pair" "ssh_key" {
  key_name   = "${var.prefix}-key"
  public_key = file(var.ssh_public_key_path)
}

# Create EC2 instances
resource "aws_instance" "frontend" {
  ami                    = var.ami_id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.public_subnet_a.id
  vpc_security_group_ids = [aws_security_group.frontend_sg.id]
  key_name               = aws_key_pair.ssh_key.key_name

  user_data = templatefile("${path.module}/scripts/frontend_init.sh", {
    backend_url = "http://${aws_instance.backend.private_ip}:5000"
    domain_name = var.domain_name
    email       = var.email
    admin_username = var.admin_username
  })

  tags = {
    Name = "${var.prefix}-frontend"
  }

  depends_on = [aws_instance.backend]
}

resource "aws_instance" "backend" {
  ami                    = var.ami_id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.public_subnet_a.id
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  key_name               = aws_key_pair.ssh_key.key_name

  user_data = templatefile("${path.module}/scripts/backend_init.sh", {
    mysql_host       = aws_db_instance.mysql.address
    mysql_user       = "mysqladmin"
    mysql_password   = var.mysql_admin_password
    mysql_database   = "adhere"
    mongodb_host     = aws_docdb_cluster.mongodb.endpoint
    mongodb_username = "docdbadmin"
    mongodb_password = var.mongodb_admin_password
    redis_host       = aws_elasticache_cluster.redis.cache_nodes.0.address
    redis_port       = aws_elasticache_cluster.redis.cache_nodes.0.port
    redis_password   = ""  # AWS ElastiCache doesn't use passwords by default
    admin_username   = var.admin_username
    domain_name      = var.domain_name
  })

  tags = {
    Name = "${var.prefix}-backend"
  }
}

# Create RDS MySQL
resource "aws_db_subnet_group" "mysql" {
  name       = "${var.prefix}-mysql-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_a.id, aws_subnet.private_subnet_b.id]

  tags = {
    Name = "${var.prefix}-mysql-subnet-group"
  }
}

# Automatically generate a compliant password, uncomment the below
#resource "random_password" "mysql_password" {
#  length           = 16
#  special          = true
#  override_special = "!#$%&*()-_=+[]{}<>:?"
#}

resource "aws_db_instance" "mysql" {
  identifier              = "${var.prefix}-mysql"
  allocated_storage       = 20
  storage_type            = "gp2"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.small"
  db_name                 = "adhere"
  username                = "mysqladmin"
  password                = var.mysql_admin_password
  vpc_security_group_ids  = [aws_security_group.db_sg.id]
  db_subnet_group_name    = aws_db_subnet_group.mysql.name
  skip_final_snapshot     = true
  backup_retention_period = 7
  multi_az                = false

  tags = {
    Name = "${var.prefix}-mysql"
  }
}

# Create DocumentDB (MongoDB-compatible)
resource "aws_docdb_subnet_group" "mongodb" {
  name       = "${var.prefix}-docdb-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_a.id, aws_subnet.private_subnet_b.id]

  tags = {
    Name = "${var.prefix}-docdb-subnet-group"
  }
}

resource "aws_docdb_cluster" "mongodb" {
  cluster_identifier      = "${var.prefix}-mongodb-${random_string.unique_suffix.result}"
  engine                  = "docdb"
  master_username         = "docdbadmin"
  master_password         = var.mongodb_admin_password
  backup_retention_period = 7
  preferred_backup_window = "07:00-09:00"
  skip_final_snapshot     = true
  db_subnet_group_name    = aws_docdb_subnet_group.mongodb.name
  vpc_security_group_ids  = [aws_security_group.db_sg.id]

  tags = {
    Name = "${var.prefix}-mongodb"
  }
}

resource "aws_docdb_cluster_instance" "mongodb_instances" {
  count              = 1
  identifier         = "${var.prefix}-mongodb-${count.index}"
  cluster_identifier = aws_docdb_cluster.mongodb.id
  instance_class     = "db.t3.medium"

  tags = {
    Name = "${var.prefix}-mongodb-${count.index}"
  }
}

# Create ElastiCache (Redis)
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.prefix}-redis-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_a.id, aws_subnet.private_subnet_b.id]
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.prefix}-redis-${random_string.unique_suffix.result}"
  engine               = "redis"
  node_type            = "cache.t3.small"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis6.x"
  engine_version       = "6.0"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [aws_security_group.db_sg.id]

  tags = {
    Name = "${var.prefix}-redis"
  }
}

# Create Route53 zone and records
resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = {
    Name = "${var.prefix}-route53-zone"
  }
}

# Allocate Elastic IPs for instances
resource "aws_eip" "frontend_eip" {
  instance = aws_instance.frontend.id
  
  tags = {
    Name = "${var.prefix}-frontend-eip"
  }
}

resource "aws_eip" "backend_eip" {
  instance = aws_instance.backend.id
  
  tags = {
    Name = "${var.prefix}-backend-eip"
  }
}

# Create Route53 records
# Update Route53 records to point to CloudFront instead of directly to EC2
resource "aws_route53_record" "frontend" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = 300
  
  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"
  ttl     = 300
  
  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = [aws_eip.backend_eip.public_ip]
}

# Outputs
output "frontend_public_ip" {
  value = aws_eip.frontend_eip.public_ip
}

output "backend_public_ip" {
  value = aws_eip.backend_eip.public_ip
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
  value     = aws_docdb_cluster.mongodb.master_password
  sensitive = true
}

output "redis_endpoint" {
  value = aws_elasticache_cluster.redis.cache_nodes.0.address
}

output "redis_port" {
  value = aws_elasticache_cluster.redis.cache_nodes.0.port
}