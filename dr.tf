#####################################
# Disaster Recovery Infrastructure
#####################################

# Create VPC in secondary region for DR
resource "aws_vpc" "dr_vpc" {
  provider             = aws.dr_region
  cidr_block           = "10.1.0.0/16"  # Different CIDR from primary
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.prefix}-dr-vpc"
  }
}

# Create Internet Gateway for DR
resource "aws_internet_gateway" "dr_igw" {
  provider = aws.dr_region
  vpc_id   = aws_vpc.dr_vpc.id

  tags = {
    Name = "${var.prefix}-dr-igw"
  }
}

# Create subnets in DR region
resource "aws_subnet" "dr_public_subnet_a" {
  provider                = aws.dr_region
  vpc_id                  = aws_vpc.dr_vpc.id
  cidr_block              = "10.1.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.secondary_region}a"

  tags = {
    Name = "${var.prefix}-dr-public-subnet-a"
  }
}

resource "aws_subnet" "dr_public_subnet_b" {
  provider                = aws.dr_region
  vpc_id                  = aws_vpc.dr_vpc.id
  cidr_block              = "10.1.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.secondary_region}b"

  tags = {
    Name = "${var.prefix}-dr-public-subnet-b"
  }
}

resource "aws_subnet" "dr_private_subnet_a" {
  provider                = aws.dr_region
  vpc_id                  = aws_vpc.dr_vpc.id
  cidr_block              = "10.1.3.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "${var.secondary_region}a"

  tags = {
    Name = "${var.prefix}-dr-private-subnet-a"
  }
}

resource "aws_subnet" "dr_private_subnet_b" {
  provider                = aws.dr_region
  vpc_id                  = aws_vpc.dr_vpc.id
  cidr_block              = "10.1.4.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "${var.secondary_region}b"

  tags = {
    Name = "${var.prefix}-dr-private-subnet-b"
  }
}

# Create route tables for DR
resource "aws_route_table" "dr_public_rt" {
  provider = aws.dr_region
  vpc_id   = aws_vpc.dr_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dr_igw.id
  }

  tags = {
    Name = "${var.prefix}-dr-public-rt"
  }
}

# Associate route table with DR public subnets
resource "aws_route_table_association" "dr_public_a" {
  provider       = aws.dr_region
  subnet_id      = aws_subnet.dr_public_subnet_a.id
  route_table_id = aws_route_table.dr_public_rt.id
}

resource "aws_route_table_association" "dr_public_b" {
  provider       = aws.dr_region
  subnet_id      = aws_subnet.dr_public_subnet_b.id
  route_table_id = aws_route_table.dr_public_rt.id
}

# Create NAT Gateway for DR
resource "aws_eip" "dr_nat_eip" {
  provider = aws.dr_region
  
  tags = {
    Name = "${var.prefix}-dr-nat-eip"
  }
}

resource "aws_nat_gateway" "dr_nat_gw" {
  provider      = aws.dr_region
  allocation_id = aws_eip.dr_nat_eip.id
  subnet_id     = aws_subnet.dr_public_subnet_a.id

  tags = {
    Name = "${var.prefix}-dr-nat-gw"
  }
}

# Create private route table with NAT Gateway for DR
resource "aws_route_table" "dr_private_rt" {
  provider = aws.dr_region
  vpc_id   = aws_vpc.dr_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.dr_nat_gw.id
  }

  tags = {
    Name = "${var.prefix}-dr-private-rt"
  }
}

# Associate route table with DR private subnets
resource "aws_route_table_association" "dr_private_a" {
  provider       = aws.dr_region
  subnet_id      = aws_subnet.dr_private_subnet_a.id
  route_table_id = aws_route_table.dr_private_rt.id
}

resource "aws_route_table_association" "dr_private_b" {
  provider       = aws.dr_region
  subnet_id      = aws_subnet.dr_private_subnet_b.id
  route_table_id = aws_route_table.dr_private_rt.id
}

# Create security groups for DR
resource "aws_security_group" "dr_frontend_sg" {
  provider    = aws.dr_region
  name        = "${var.prefix}-dr-frontend-sg"
  description = "Security group for DR frontend server"
  vpc_id      = aws_vpc.dr_vpc.id

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
    Name = "${var.prefix}-dr-frontend-sg"
  }
}

resource "aws_security_group" "dr_backend_sg" {
  provider    = aws.dr_region
  name        = "${var.prefix}-dr-backend-sg"
  description = "Security group for DR backend server"
  vpc_id      = aws_vpc.dr_vpc.id

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
    Name = "${var.prefix}-dr-backend-sg"
  }
}

resource "aws_security_group" "dr_db_sg" {
  provider    = aws.dr_region
  name        = "${var.prefix}-dr-db-sg"
  description = "Security group for DR databases"
  vpc_id      = aws_vpc.dr_vpc.id

  # MySQL
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.dr_backend_sg.id]
  }

  # MongoDB
  ingress {
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.dr_backend_sg.id]
  }

  # Redis
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.dr_backend_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.prefix}-dr-db-sg"
  }
}

# Create key pair for SSH in DR region
resource "aws_key_pair" "dr_ssh_key" {
  provider   = aws.dr_region
  key_name   = "${var.prefix}-dr-key"
  public_key = file(var.ssh_public_key_path)
}

# Create DR database resources
resource "aws_db_subnet_group" "dr_mysql" {
  provider    = aws.dr_region
  name        = "${var.prefix}-dr-mysql-subnet-group"
  subnet_ids  = [aws_subnet.dr_private_subnet_a.id, aws_subnet.dr_private_subnet_b.id]

  tags = {
    Name = "${var.prefix}-dr-mysql-subnet-group"
  }
}

# If using pilot-light mode, create a smaller read replica
resource "aws_db_instance" "dr_mysql" {
  provider                      = aws.dr_region
  count                         = var.dr_mode == "pilot-light" ? 1 : 0
  identifier                    = "${var.prefix}-dr-mysql"
  instance_class                = "db.t3.small"
  vpc_security_group_ids        = [aws_security_group.dr_db_sg.id]
  db_subnet_group_name          = aws_db_subnet_group.dr_mysql.name
  skip_final_snapshot           = true
  replicate_source_db           = aws_db_instance.mysql.arn
  
  tags = {
    Name = "${var.prefix}-dr-mysql"
  }
}

# If using active-passive mode, create a full instance
resource "aws_db_instance" "dr_mysql_full" {
  provider                      = aws.dr_region
  count                         = var.dr_mode == "active-passive" ? 1 : 0
  identifier                    = "${var.prefix}-dr-mysql"
  allocated_storage             = 20
  storage_type                  = "gp2"
  engine                        = "mysql"
  engine_version                = "8.0"
  instance_class                = "db.t3.small"
  db_name                       = "adhere"
  username                      = "mysqladmin"
  password                      = var.mysql_admin_password
  vpc_security_group_ids        = [aws_security_group.dr_db_sg.id]
  db_subnet_group_name          = aws_db_subnet_group.dr_mysql.name
  skip_final_snapshot           = true
  backup_retention_period       = 7
  multi_az                      = false

  tags = {
    Name = "${var.prefix}-dr-mysql"
  }
}

# Setup DocumentDB in DR region
resource "aws_docdb_subnet_group" "dr_mongodb" {
  provider    = aws.dr_region
  name        = "${var.prefix}-dr-docdb-subnet-group"
  subnet_ids  = [aws_subnet.dr_private_subnet_a.id, aws_subnet.dr_private_subnet_b.id]

  tags = {
    Name = "${var.prefix}-dr-docdb-subnet-group"
  }
}

resource "aws_docdb_cluster" "dr_mongodb" {
  provider                  = aws.dr_region
  count                     = var.dr_mode == "active-passive" ? 1 : 0
  cluster_identifier        = "${var.prefix}-dr-mongodb-${random_string.unique_suffix.result}"
  engine                    = "docdb"
  master_username           = "docdbadmin"
  master_password           = var.mongodb_admin_password
  backup_retention_period   = 7
  preferred_backup_window   = "07:00-09:00"
  skip_final_snapshot       = true
  db_subnet_group_name      = aws_docdb_subnet_group.dr_mongodb.name
  vpc_security_group_ids    = [aws_security_group.dr_db_sg.id]

  tags = {
    Name = "${var.prefix}-dr-mongodb"
  }
}

# For pilot-light, create a smaller DocumentDB cluster
resource "aws_docdb_cluster" "dr_mongodb_pilot" {
  provider                  = aws.dr_region
  count                     = var.dr_mode == "pilot-light" ? 1 : 0
  cluster_identifier        = "${var.prefix}-dr-mongodb-${random_string.unique_suffix.result}"
  engine                    = "docdb"
  master_username           = "docdbadmin"
  master_password           = var.mongodb_admin_password
  backup_retention_period   = 7
  preferred_backup_window   = "07:00-09:00"
  skip_final_snapshot       = true
  db_subnet_group_name      = aws_docdb_subnet_group.dr_mongodb.name
  vpc_security_group_ids    = [aws_security_group.dr_db_sg.id]
  # No instances in pilot light mode - will create when needed

  tags = {
    Name = "${var.prefix}-dr-mongodb-pilot"
  }
}

# Create ElastiCache in DR region
resource "aws_elasticache_subnet_group" "dr_redis" {
  provider    = aws.dr_region
  name        = "${var.prefix}-dr-redis-subnet-group"
  subnet_ids  = [aws_subnet.dr_private_subnet_a.id, aws_subnet.dr_private_subnet_b.id]
}

resource "aws_elasticache_cluster" "dr_redis" {
  provider            = aws.dr_region
  count               = var.dr_mode == "active-passive" ? 1 : 0
  cluster_id          = "${var.prefix}-dr-redis-${random_string.unique_suffix.result}"
  engine              = "redis"
  node_type           = "cache.t3.small"
  num_cache_nodes     = 1
  parameter_group_name = "default.redis6.x"
  engine_version      = "6.0"
  port                = 6379
  subnet_group_name   = aws_elasticache_subnet_group.dr_redis.name
  security_group_ids  = [aws_security_group.dr_db_sg.id]

  tags = {
    Name = "${var.prefix}-dr-redis"
  }
}