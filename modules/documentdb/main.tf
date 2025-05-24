# modules/documentdb/main.tf - DocumentDB Module

# DocumentDB Subnet Group
resource "aws_docdb_subnet_group" "main" {
  name       = "${var.name_prefix}-${var.environment}-docdb-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.environment}-docdb-subnet-group"
  })
}

# DocumentDB Cluster Parameter Group
resource "aws_docdb_cluster_parameter_group" "main" {
  family = "docdb5.0"
  name   = "${var.name_prefix}-${var.environment}-docdb-params"

  parameter {
    name  = "tls"
    value = "enabled"
  }

  parameter {
    name  = "ttl_monitor"
    value = "enabled"
  }

  tags = var.tags
}

# DocumentDB Cluster
resource "aws_docdb_cluster" "main" {
  cluster_identifier = "${var.name_prefix}-${var.environment}-docdb"
  engine             = "docdb"
  engine_version     = "5.0.0"

  # Master credentials
  master_username = var.master_username
  master_password = var.master_password
  port            = 27017

  # Network configuration
  db_subnet_group_name   = aws_docdb_subnet_group.main.name
  vpc_security_group_ids = var.security_group_ids

  # Backup configuration
  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"

  # Parameter group
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.main.name

  # Encryption
  storage_encrypted = true

  # Deletion configuration
  deletion_protection       = false # Set to true for production
  skip_final_snapshot       = true  # Set to false for production
  final_snapshot_identifier = "${var.name_prefix}-${var.environment}-docdb-final-snapshot"

  # Enable CloudWatch logs
  enabled_cloudwatch_logs_exports = ["audit", "profiler"]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.environment}-docdb"
  })
}

# DocumentDB Cluster Instances (simplified)
resource "aws_docdb_cluster_instance" "cluster_instances" {
  count              = var.cluster_size
  identifier         = "${var.name_prefix}-${var.environment}-docdb-${count.index}"
  cluster_identifier = aws_docdb_cluster.main.id
  instance_class     = var.instance_class

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.environment}-docdb-${count.index}"
  })
}

# CloudWatch Alarms for DocumentDB
resource "aws_cloudwatch_metric_alarm" "documentdb_cpu" {
  count               = var.cluster_size
  alarm_name          = "${var.name_prefix}-${var.environment}-docdb-cpu-${count.index}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/DocDB"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors DocumentDB CPU utilization"

  dimensions = {
    DBInstanceIdentifier = aws_docdb_cluster_instance.cluster_instances[count.index].identifier
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "documentdb_connections" {
  alarm_name          = "${var.name_prefix}-${var.environment}-docdb-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/DocDB"
  period              = "120"
  statistic           = "Average"
  threshold           = "50"
  alarm_description   = "This metric monitors DocumentDB connection count"

  dimensions = {
    DBClusterIdentifier = aws_docdb_cluster.main.cluster_identifier
  }

  tags = var.tags
}
