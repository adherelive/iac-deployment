#!/bin/bash
# fix-validation-errors.sh - Quick fix for Terraform validation errors

echo "Fixing Terraform validation errors..."

# Fix 1: Update main.tf DocumentDB module call
echo "Updating DocumentDB module in main.tf..."

# Create a temporary file with the corrected DocumentDB module
cat > temp_documentdb_fix.txt << 'EOF'
# DocumentDB Module (MongoDB replacement)
module "documentdb" {
  source = "./modules/documentdb"
  
  name_prefix           = local.name_prefix
  environment          = local.environment
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  security_group_ids   = [module.security_groups.documentdb_security_group_id]
  
  master_username  = var.mongodb_username
  master_password  = var.mongodb_password
  mongodb_database = var.mysql_database  # Using same database name for consistency
  
  tags = local.common_tags
}
EOF

# Fix 2: Create modules/documentdb/variables.tf with correct variables
echo "Creating DocumentDB module variables..."

mkdir -p modules/documentdb

cat > modules/documentdb/variables.tf << 'EOF'
variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs of the private subnets"
  type        = list(string)
}

variable "security_group_ids" {
  description = "IDs of the security groups"
  type        = list(string)
}

variable "master_username" {
  description = "Master username"
  type        = string
}

variable "master_password" {
  description = "Master password"
  type        = string
  sensitive   = true
}

variable "mongodb_database" {
  description = "MongoDB database name"
  type        = string
  default     = "adhere"
}

variable "instance_class" {
  description = "DocumentDB instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "cluster_size" {
  description = "Number of instances in the cluster"
  type        = number
  default     = 1
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
EOF

# Fix 3: Update modules/documentdb/outputs.tf
cat > modules/documentdb/outputs.tf << 'EOF'
output "endpoint" {
  description = "DocumentDB cluster endpoint"
  value       = aws_docdb_cluster.main.endpoint
}

output "port" {
  description = "DocumentDB port"
  value       = aws_docdb_cluster.main.port
}

output "cluster_id" {
  description = "DocumentDB cluster identifier"
  value       = aws_docdb_cluster.main.cluster_identifier
}
EOF

# Fix 4: Create all missing module directories and basic files
echo "Creating missing module structure..."

modules=("vpc" "security-groups" "rds" "documentdb" "ecs" "codebuild" "acm" "route53")

for module in "${modules[@]}"; do
    mkdir -p "modules/$module"
    
    # Create basic outputs.tf if it doesn't exist
    if [[ ! -f "modules/$module/outputs.tf" ]]; then
        touch "modules/$module/outputs.tf"
    fi
    
    # Create basic variables.tf if it doesn't exist
    if [[ ! -f "modules/$module/variables.tf" ]]; then
        touch "modules/$module/variables.tf"
    fi
    
    # Create basic main.tf if it doesn't exist
    if [[ ! -f "modules/$module/main.tf" ]]; then
        touch "modules/$module/main.tf"
    fi
done

echo "Module structure created:"
find modules -name "*.tf" | sort

echo ""
echo "Now you need to manually update main.tf to fix the DocumentDB module call."
echo "Replace the DocumentDB module section with the content from temp_documentdb_fix.txt"
echo ""
echo "After that, run:"
echo "terraform validate"

# Clean up temp file
rm -f temp_documentdb_fix.txt

echo "Fix script completed!"