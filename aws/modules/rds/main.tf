# modules/rds/main.tf - RDS Module (Fixed)

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.name_prefix}-${var.environment}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.environment}-db-subnet-group"
  })
}

# DB Parameter Group
resource "aws_db_parameter_group" "main" {
  family = "mysql8.0"
  name   = "${var.name_prefix}-${var.environment}-mysql-params"

  parameter {
    name  = "innodb_buffer_pool_size"
    value = "{DBInstanceClassMemory*3/4}"
  }

  parameter {
    name  = "max_connections"
    value = "200"
  }

  tags = var.tags
}

# Local values to determine Performance Insights support
locals {
  # Define instance classes that support Performance Insights
  performance_insights_supported_classes = [
    "db.t3.small", "db.t3.medium", "db.t3.large", "db.t3.xlarge", "db.t3.2xlarge",
    "db.m5.large", "db.m5.xlarge", "db.m5.2xlarge", "db.m5.4xlarge", "db.m5.8xlarge", "db.m5.12xlarge", "db.m5.16xlarge", "db.m5.24xlarge",
    "db.m6i.large", "db.m6i.xlarge", "db.m6i.2xlarge", "db.m6i.4xlarge", "db.m6i.8xlarge", "db.m6i.12xlarge", "db.m6i.16xlarge", "db.m6i.24xlarge", "db.m6i.32xlarge",
    "db.r5.large", "db.r5.xlarge", "db.r5.2xlarge", "db.r5.4xlarge", "db.r5.8xlarge", "db.r5.12xlarge", "db.r5.16xlarge", "db.r5.24xlarge",
    "db.r6i.large", "db.r6i.xlarge", "db.r6i.2xlarge", "db.r6i.4xlarge", "db.r6i.8xlarge", "db.r6i.12xlarge", "db.r6i.16xlarge", "db.r6i.24xlarge", "db.r6i.32xlarge"
  ]

  # Check if current instance class supports Performance Insights
  performance_insights_enabled = contains(local.performance_insights_supported_classes, var.instance_class)

  # Enhanced monitoring is also limited to certain instance classes
  enhanced_monitoring_enabled = contains(local.performance_insights_supported_classes, var.instance_class)
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier = "${var.name_prefix}-${var.environment}-mysql"

  # Database Configuration
  engine         = "mysql"
  engine_version = "8.0.35"
  instance_class = var.instance_class

  # Storage Configuration
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  # Database Details
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 3306

  # Network Configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = var.security_group_ids
  publicly_accessible    = false

  # Backup Configuration
  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  # Multi-AZ Configuration
  multi_az = var.enable_multi_az

  # Parameter Group
  parameter_group_name = aws_db_parameter_group.main.name

  # Conditional Monitoring based on instance class
  monitoring_interval = local.enhanced_monitoring_enabled ? 60 : 0
  monitoring_role_arn = local.enhanced_monitoring_enabled ? aws_iam_role.enhanced_monitoring[0].arn : null

  # Conditional Performance Insights
  performance_insights_enabled          = local.performance_insights_enabled
  performance_insights_retention_period = local.performance_insights_enabled ? 7 : null

  # Deletion Configuration
  deletion_protection       = false # Set to true for production
  skip_final_snapshot       = true  # Set to false for production
  final_snapshot_identifier = "${var.name_prefix}-${var.environment}-mysql-final-snapshot"

  # Enable automated backups
  copy_tags_to_snapshot = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.environment}-mysql"
  })
}

# Enhanced Monitoring Role (conditional creation)
resource "aws_iam_role" "enhanced_monitoring" {
  count = local.enhanced_monitoring_enabled ? 1 : 0
  name  = "${var.name_prefix}-${var.environment}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "enhanced_monitoring" {
  count      = local.enhanced_monitoring_enabled ? 1 : 0
  role       = aws_iam_role.enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# CloudWatch Alarms for RDS
resource "aws_cloudwatch_metric_alarm" "database_cpu" {
  alarm_name          = "${var.name_prefix}-${var.environment}-mysql-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors RDS CPU utilization"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "database_connections" {
  alarm_name          = "${var.name_prefix}-${var.environment}-mysql-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors RDS connection count"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = var.tags
}