# Domain & SSL Configuration Guide

## Overview

This guide walks you through setting up your domain and SSL certificate in phases, so you can deploy infrastructure first and configure DNS later.

## Phase 1: Deploy Infrastructure Without SSL (Immediate)

### Step 1: Initial Deployment

Your Terraform will deploy successfully without the domain being configured. The infrastructure will be accessible via the ALB DNS name.

```bash
# Deploy infrastructure first
./deploy-infrastructure.sh apply
```

### Step 2: Get ALB Information

After deployment, get the load balancer details:

```bash
# Get ALB DNS name and zone ID
terraform output alb_dns_name
terraform output alb_zone_id

# Example output:
# alb_dns_name = "adherelive-prod-alb-1234567890.ap-south-1.elb.amazonaws.com"
# alb_zone_id = "ZP97RAFLXTNZK"
```

### Step 3: Test Application via ALB DNS

Your application will be accessible immediately via HTTP:

```bash
# Test frontend
curl http://adherelive-prod-alb-1234567890.ap-south-1.elb.amazonaws.com

# Test backend API
curl http://adherelive-prod-alb-1234567890.ap-south-1.elb.amazonaws.com/api/health
```

## Phase 2: Configure Domain on GoDaddy

### Step 1: Two Options for DNS Configuration

#### Option A: Use AWS Route53 (Recommended)

**Benefits**: Automatic SSL certificate validation, better AWS integration

1. **Transfer DNS to Route53:**
   ```bash
   # Create hosted zone
   aws route53 create-hosted-zone --name adhere.live --caller-reference $(date +%s)
   ```

2. **Get Route53 Name Servers:**
   ```bash
   aws route53 get-hosted-zone --id /hostedzone/YOUR_ZONE_ID
   ```

3. **Update GoDaddy DNS:**
   - Log into GoDaddy
   - Go to DNS Management for adhere.live
   - Change nameservers to the Route53 ones provided

#### Option B: Keep GoDaddy DNS (Manual Configuration)

1. **Get ALB IP Address (if needed):**
   ```bash
   # ALBs use DNS names, but you can get IP for testing
   nslookup adherelive-prod-alb-1234567890.ap-south-1.elb.amazonaws.com
   ```

2. **Configure GoDaddy DNS:**
   - Log into GoDaddy DNS Management
   - Add CNAME record: `test.adhere.live` → `adherelive-prod-alb-1234567890.ap-south-1.elb.amazonaws.com`
   - Or add A record with ALB IP (not recommended as IPs can change)

### Step 2: Verify DNS Propagation

```bash
# Check DNS propagation
dig test.adhere.live

# Should return ALB address
nslookup test.adhere.live
```

## Phase 3: Enable SSL Certificate

### Step 1: Choose SSL Option

#### Option A: AWS Certificate Manager (Recommended - Free)

**Update terraform.tfvars:**
```hcl
# Enable SSL with ACM
enable_ssl = true
domain_name = "adhere.live"
subdomain = "test"
```

**Update main.tf (uncomment the ACM and Route53 modules):**
```hcl
# Uncomment these modules
module "acm" {
  source = "./modules/acm"
  domain_name = "${var.subdomain}.${var.domain_name}"
  tags = local.common_tags
}

module "route53" {
  source = "./modules/route53"
  domain_name = var.domain_name
  subdomain = var.subdomain
  alb_dns_name = module.ecs.alb_dns_name
  alb_zone_id = module.ecs.alb_zone_id
  certificate_arn = module.acm.certificate_arn
  tags = local.common_tags
}
```

**Deploy SSL configuration:**
```bash
./deploy-infrastructure.sh apply
```

#### Option B: Let's Encrypt with Certbot (Alternative)

If you prefer Let's Encrypt, you can use the provided script, but **AWS Certificate Manager is recommended** because:

- **Free and automatic renewal**
- **Integrated with AWS services**
- **No manual certificate management**
- **Faster setup process**

### Step 2: Verify SSL Configuration

After enabling SSL, test your secure connection:

```bash
# Test HTTPS
curl -I https://test.adhere.live

# Should show SSL certificate information
openssl s_client -connect test.adhere.live:443 -servername test.adhere.live
```

## Complete Step-by-Step Workflow

### Phase 1: Infrastructure Without SSL ✅ (Works Immediately)

```bash
# 1. Deploy base infrastructure
./deploy-infrastructure.sh apply

# 2. Test via ALB DNS name
ALB_DNS=$(terraform output -raw alb_dns_name)
curl http://$ALB_DNS
curl http://$ALB_DNS/api/health

# 3. Build and deploy applications  
./build-and-deploy.sh prod akshay-gaurav-latest-changes
```

**Result**: Your application is live and accessible via ALB DNS name

### Phase 2: Configure Domain ⏳ (When Ready)

#### Option A: Route53 (Recommended)
```bash
# 1. Create Route53 hosted zone
aws route53 create-hosted-zone --name adhere.live --caller-reference $(date +%s)

# 2. Get nameservers and update GoDaddy
aws route53 list-hosted-zones --query 'HostedZones[?Name==`adhere.live.`]'

# 3. Wait for DNS propagation (15 minutes - 48 hours)
```

#### Option B: GoDaddy DNS
```bash
# 1. Add CNAME in GoDaddy DNS:
# Name: test
# Value: adherelive-prod-alb-1234567890.ap-south-1.elb.amazonaws.com
# TTL: 600 (10 minutes)

# 2. Wait for DNS propagation
```

### Phase 3: Enable SSL ⏳ (After DNS Works)

```bash
# 1. Verify domain resolves
dig test.adhere.live

# 2. Uncomment SSL modules in main.tf
# 3. Update terraform.tfvars to enable SSL
# 4. Apply changes
./deploy-infrastructure.sh apply

# 5. Test HTTPS
curl -I https://test.adhere.live
```

## Important Notes

### 1. No Infrastructure Blocking Issues

✅ **Your infrastructure will deploy successfully even without domain configuration**
✅ **Application will be accessible via ALB DNS name immediately**
✅ **You can test and develop while DNS propagates**

### 2. DNS Propagation Timeline

- **Local**: 5-15 minutes
- **Regional**: 30 minutes - 2 hours  
- **Global**: 24-48 hours maximum

### 3. Testing During Setup

```bash
# Test application without custom domain
ALB_DNS=$(terraform output -raw alb_dns_name)

# Frontend
curl http://$ALB_DNS

# Backend API  
curl http://$ALB_DNS/api/health

# Check if domain resolves to ALB
dig test.adhere.live
```

## Troubleshooting

### DNS Not Resolving
```bash
# Check current DNS resolution
dig test.adhere.live @8.8.8.8

# Check ALB IP
dig adherelive-prod-alb-1234567890.ap-south-1.elb.amazonaws.com @8.8.8.8

# Test with different DNS servers
dig test.adhere.live @1.1.1.1
```

### SSL Certificate Issues
```bash
# Check certificate status in ACM
aws acm list-certificates --region ap-south-1

# Check certificate validation
aws acm describe-certificate --certificate-arn YOUR_CERT_ARN --region ap-south-1
```

### Application Health Issues
```bash
# Check ECS service status
aws ecs describe-services --cluster adherelive-prod-cluster --services adherelive-prod-backend

# Check target group health
aws elbv2 describe-target-health --target-group-arn YOUR_TG_ARN
```

## Recommended Approach

1. **Deploy infrastructure immediately** (Phase 1)
2. **Test application via ALB DNS** while configuring domain
3. **Configure Route53 hosting** (recommended over GoDaddy DNS)
4. **Enable SSL with ACM** (free and automatic)
5. **Gradually migrate to HTTPS** once everything works

This approach ensures you can start testing and developing immediately while the DNS and SSL setup happens in parallel!