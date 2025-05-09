provider "aws" {
  region = var.region
}

# Provider for CloudFront certificates (must be in us-east-1)
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

# Provider for secondary region
provider "aws" {
  alias  = "dr_region"
  region = var.secondary_region
}

resource "random_string" "unique_suffix" {
  length  = 6
  special = false
  upper   = false
}

#####################################
# Primary Region Infrastructure
#####################################

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
