# Terraform Init Troubleshooting Guide

## Common Issues and Solutions

### 1. Module Path Issues

**Error**: `Module not found` or `Could not load module`

**Solution**: Check directory structure
```bash
# Verify your directory structure looks like this:
adherelive-infrastructure/
├── main.tf
├── variables.tf
├── outputs.tf
├── deploy-infrastructure.sh
└── modules/
    ├── vpc/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── security-groups/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── rds/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── documentdb/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── ecs/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── codebuild/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── acm/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── route53/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

### 2. AWS Provider Version Issues

**Error**: `Failed to query available provider packages`

**Solution**: Update provider version in main.tf
```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}
```

### 3. AWS Credentials Issues

**Error**: `No valid credential sources found`

**Solution**: Configure AWS credentials
```bash
# Option 1: AWS CLI configure
aws configure

# Option 2: Environment variables
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
export AWS_DEFAULT_REGION=ap-south-1

# Option 3: Check existing credentials
aws sts get-caller-identity
```

### 4. Network/Firewall Issues

**Error**: `Failed to install provider` or `Network timeout`

**Solution**: Check network connectivity
```bash
# Test connectivity to Terraform registry
curl -I https://registry.terraform.io

# If behind corporate firewall, configure proxy
export HTTP_PROXY=http://your-proxy:port
export HTTPS_PROXY=http://your-proxy:port
```

### 5. Terraform Cache Issues

**Error**: `Failed to read schema` or corrupt state

**Solution**: Clear Terraform cache
```bash
# Remove .terraform directory
rm -rf .terraform/

# Remove lock file
rm -f .terraform.lock.hcl

# Re-run init
terraform init
```

### 6. Syntax Errors in Configuration

**Error**: `Configuration is invalid`

**Solution**: Validate syntax
```bash
# Check for syntax errors
terraform validate

# Format files
terraform fmt -recursive

# Check specific file
terraform fmt -check main.tf
```

## Step-by-Step Debugging

### Step 1: Basic Checks
```bash
# Check Terraform version
terraform version

# Check AWS CLI version
aws --version

# Check current directory
pwd
ls -la
```

### Step 2: Minimal Test
Create a minimal `test-main.tf` to isolate the issue:
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

# Test data source
data "aws_caller_identity" "current" {}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}
```

```bash
# Test with minimal config
terraform init
terraform plan
```

### Step 3: Module-by-Module Testing

If modules are causing issues, test them individually:

```bash
# Test VPC module only
cd modules/vpc
terraform init
terraform validate
cd ../..
```

## Quick Fix Commands

```bash
# Complete reset (run from project root)
rm -rf .terraform/
rm -f .terraform.lock.hcl
rm -f terraform.tfstate*

# Fresh start
terraform init
terraform validate
terraform fmt -recursive
```

## Common Error Messages and Solutions

### Error: "Module not found: vpc"
```bash
# Check if modules directory exists
ls -la modules/

# Ensure main.tf is in the right location
grep -n "module.*vpc" main.tf
```

### Error: "provider registry.terraform.io/hashicorp/aws"
```bash
# Clear provider cache
rm -rf .terraform/providers/

# Re-initialize
terraform init
```

### Error: "Backend configuration changed"
```bash
# If you have backend configuration issues
terraform init -reconfigure

# Or migrate state
terraform init -migrate-state
```

### Error: "Invalid provider configuration"
```bash
# Check AWS credentials
aws sts get-caller-identity

# Check region setting
aws configure get region
```

## Environment Setup Checklist

- [ ] Terraform installed (version 1.0+)
- [ ] AWS CLI installed and configured
- [ ] Correct directory structure
- [ ] All module files present
- [ ] AWS credentials configured
- [ ] Correct AWS region set
- [ ] Network connectivity to Terraform registry

## Create Missing Files Script

If you're missing some files, here's a script to create the basic structure:

```bash
#!/bin/bash
# create-terraform-structure.sh

# Create directory structure
mkdir -p modules/{vpc,security-groups,rds,documentdb,ecs,codebuild,acm,route53}

# Create basic module files
for module in vpc security-groups rds documentdb ecs codebuild acm route53; do
    touch modules/$module/{main.tf,variables.tf,outputs.tf}
done

echo "Basic Terraform structure created!"
echo "Now copy the provided configurations into each file."
```

## Getting Help

If you're still having issues, please share:

1. **Exact error message**
2. **Terraform version**: `terraform version`
3. **Directory structure**: `find . -name "*.tf" | head -20`
4. **Current directory**: `pwd && ls -la`

This will help me provide a more specific solution to your `terraform init` issue.