# Create key pair for SSH
resource "aws_key_pair" "ssh_key" {
  key_name   = "${var.prefix}-key"
  public_key = file(var.ssh_public_key_path)
}

# Create EC2 instances
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
    mongodb_username = aws_docdb_cluster.mongodb.master_username
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

# Create RDS MySQL
resource "aws_db_subnet_group" "mysql" {
  name       = "${var.prefix}-mysql-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_a.id, aws_subnet.private_subnet_b.id]

  tags = {
    Name = "${var.prefix}-mysql-subnet-group"
  }
}

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