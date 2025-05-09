# AWS Deployment Guide for AdhereLive

This guide walks you through deploying your AdhereLive application stack on AWS using Terraform, with CloudFront and Disaster Recovery capabilities.

## Infrastructure Overview

This deployment creates:

1. **Primary Infrastructure** in your main AWS region:
   - VPC with public and private subnets
   - EC2 instances for frontend and backend
   - RDS MySQL, DocumentDB, and ElastiCache Redis
   - Security groups and networking components
   
2. **CloudFront Distribution** for content delivery and security:
   - WAF protection against common attacks
   - SSL/TLS termination with custom domain support
   - Global content delivery

3. **Disaster Recovery** in a secondary AWS region:
   - Either "pilot-light" or "active-passive" configuration
   - Database replication or standby instances
   - Automated failover mechanisms

## Prerequisites

Before you begin, make sure you have the following installed on your local machine:

1. *AWS CLI*: [Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
2. *Terraform*: [Installation Guide](https://learn.hashicorp.com/tutorials/terraform/install-cli)
3. *SSH Key Pair*: Generated using `ssh-keygen -t rsa -b 4096`
4. *Domain Name*: Registered domain that you control
5. *Valid Email*: For SSL certificate validation notifications

## Setup Steps

### 1. Prepare Your Environment

```bash
# Clone the repository (if applicable)
git clone https://github.com/your-repo/adherelive-aws-infrastructure.git
cd adherelive-aws-infrastructure
```

# Configure Your AWS Credentials

Ensure you have AWS credentials configured:

```bash
aws configure
```

Enter your AWS Access Key ID, Secret Access Key, default region, and output format when prompted.

### 2. Configure Your Deployment

1. Create a copy of the example variables file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

2. Edit `terraform.tfvars` with your specific values:
   - Update `region` to your preferred AWS region for primary and secondary regions
   - Update `ami_id` to a valid Ubuntu AMI for both your selected region (ensure they are valid Ubuntu AMIs)
   - DR mode: "pilot-light" (lower cost) or "active-passive" (faster recovery)
   - Set `admin_ip_address` to your IP address for SSH security
   - Set strong passwords for `mysql_admin_password` and `mongodb_admin_password`
   - Update `domain_name` with your actual domain
   - Add your email address for Let's Encrypt notifications

### 3. Initialize and Deploy

```bash
# Initialize Terraform
terraform init
'''

# Validate configuration
terraform validate

# Plan the Deployment

```bash
terraform plan -out=tfplan
```

Review the plan to make sure it's creating the resources you expect.

# Apply the Terraform Configuration

```bash
terraform apply tfplan
```

This will create all the necessary resources in AWS. The process may take 20-45 minutes to complete.

### 4. Configure DNS

After deployment completes, Terraform will output your frontend and backend IP addresses (we'll need to point your domain to AWS name servers):

1. Locate the name servers in the Terraform output:
   ```bash
   terraform output route53_nameservers
   ```

2. Update your domain registrar's DNS settings to use these name servers.
   - This enables the Route53 hosted zone to manage your domain
   - DNS propagation may take 24-48 hours

a. If your domain is registered elsewhere, add NS records pointing to the AWS Route 53 nameservers
b. If needed, configure additional DNS records through the AWS Console

### 5. Deploy Your Application Code

Once the infrastructure is ready, you need to set up SSH access to GitHub repositories on both VMs:

1. *Prepare your GitHub SSH key*:
   - Make sure you have an SSH key that has access to the AdhereLive GitHub repositories
   - If you don't have one, create it and add it to your GitHub account

2. *Deploy the SSH key to your servers*:
   - Use the provided script to deploy your GitHub SSH key to both servers:

```bash
# Get the IPs from Terraform output for the EC2 instances
BACKEND_IP=$(terraform output -raw backend_public_ip)
FRONTEND_IP=$(terraform output -raw frontend_public_ip)

# Run the SSH key deployment script
./scripts/ssh_key_setup.sh $BACKEND_IP $FRONTEND_IP ~/.ssh/github_key
```

This script will:
- Copy your GitHub SSH key to both servers
- Test the GitHub connection
- Run the deployment scripts that will:
  - Clone the repositories (adherelive-web.git for backend and adherelive-fe.git for frontend)
  - Build the Docker images using the provided Dockerfiles
  - Start the containers using Docker Compose

### 6. *Verify Deployment*:
   - Check that the applications are running by accessing:
Test your deployment:

1. Frontend website:
   - https://your-domain.com
   - Should be delivered via CloudFront

2. Backend API:
   - https://api.your-domain.com
   - Also protected by CloudFront

## Disaster Recovery Testing and Failover

The DR configuration should be tested regularly to ensure it works when needed.

### Testing Pilot-Light DR

In pilot-light mode:
1. Database replication is already running
2. In case of disaster:
   ```bash
   # SSH to the DR region and launch frontend/backend
   aws ec2 run-instances --image-id $DR_AMI_ID --instance-type t3.small --key-name $DR_KEY_NAME [other parameters]
   ```

### Testing Active-Passive DR

In active-passive mode:
1. All infrastructure is already running in both regions
2. Test failover by updating Route53:
   ```bash
   # Update Route53 record to point to DR instance
   aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch file://failover-to-dr.json
   ```

3. Sample failover-to-dr.json:
   ```json
   {
     "Changes": [
       {
         "Action": "UPSERT",
         "ResourceRecordSet": {
           "Name": "api.example.com",
           "Type": "A",
           "SetIdentifier": "primary",
           "Failover": "PRIMARY",
           "TTL": 60,
           "ResourceRecords": [
             {
               "Value": "DR_BACKEND_IP"
             }
           ]
         }
       }
     ]
   }
   ```


## Infrastructure Components

Your deployed infrastructure includes:

- *VPC* with public and private subnets across two availability zones
- *EC2 Instances* for frontend and backend applications
- *Security Groups* with configured rules for each component
- *RDS MySQL* database service
- *DocumentDB* with MongoDB API
- *ElastiCache* for Redis caching
- *Route 53* for domain management
- *Elastic IPs* associated with EC2 instances

## SSL Configuration

Let's Encrypt certificates are automatically set up for your domain. The certificates will auto-renew through a configured cron job.

## Maintenance

### Monitoring DR Status

```bash
# Check status of database replication
aws rds describe-db-instances --db-instance-identifier $(terraform output -raw mysql_endpoint | cut -d ":" -f1)

# For DocumentDB
aws docdb describe-db-clusters --db-cluster-identifier $(terraform output -raw mongodb_endpoint | cut -d ":" -f1)
```

### Updating the Application

To update your application in both regions:

1. Primary Region:
   ```bash
   ssh ubuntu@$(terraform output -raw frontend_public_ip) "sudo /app/deploy.sh"
   ssh ubuntu@$(terraform output -raw backend_public_ip) "sudo /app/deploy.sh"
   ```

2. DR Region (active-passive mode):
   ```bash
   DR_FRONTEND_IP=$(terraform output -raw dr_frontend_public_ip)
   DR_BACKEND_IP=$(terraform output -raw dr_backend_public_ip)
   
   # Only if in active-passive mode (not pilot-light)
   if [[ "$DR_FRONTEND_IP" != "Not deployed in pilot-light mode" ]]; then
     ssh ubuntu@$DR_FRONTEND_IP "sudo /app/deploy.sh"
     ssh ubuntu@$DR_BACKEND_IP "sudo /app/deploy.sh"
   fi
   ```

### Modifying Infrastructure

If you need to modify the infrastructure:

1. Update the Terraform files
2. Run `terraform plan` to see the changes
3. Apply the changes with `terraform apply`

### CloudFront Configuration

CloudFront settings can be adjusted in the AWS Console or via Terraform:

1. Adjust cache behaviors for better performance
2. Update WAF rules for additional security
3. Configure additional origins if needed

### Managing WAF Rules

The default WAF configuration includes basic protection. To add custom rules:

```bash
# Create a rule in WAF
aws wafv2 create-rule-group --name my-custom-rules --scope CLOUDFRONT --region us-east-1 --capacity 10 \
  --rules file://custom-waf-rules.json \
  --visibility-config SampledRequestsEnabled=true,CloudWatchMetricsEnabled=true,MetricName=CustomRulesMetric
```

Then update the Terraform code to include these custom rules.

### Destroying the Infrastructure

If you need to tear down the entire environment:

```bash
terraform destroy
```

*Warning*: This will delete all resources created by Terraform, including databases and their data.

## Troubleshooting

### Checking Logs

- *Application Logs*: Access Docker container logs on each VM
  ```bash
  ssh ubuntu@YOUR_VM_IP "sudo docker logs -f container_name"
  ```

- *Nginx Logs*: Check web server logs for issues
  ```bash
  ssh ubuntu@YOUR_VM_IP "sudo cat /var/log/nginx/error.log"
  ```

### SSH Access Issues

If you can't SSH into the EC2 instances:
1. Verify your IP is allowed in the Security Group
2. Check that you're using the correct SSH key
3. Confirm the instance is running in the AWS Console

### CloudFront Issues

1. **SSL Certificate Problems**:
   - Verify ACM certificate status: `aws acm describe-certificate --certificate-arn $(terraform output -raw acm_certificate_arn)`
   - Ensure DNS validation is complete

2. **Cache Behavior Issues**:
   - Check CloudFront configuration: `aws cloudfront get-distribution-config --id $(terraform output -raw cloudfront_distribution_id)`
   - Invalidate cache if needed: `aws cloudfront create-invalidation --distribution-id $(terraform output -raw cloudfront_distribution_id) --paths "/*"`

### Database Replication Issues

1. **RDS Replication Lag**:
   ```bash
   aws rds describe-db-instances --db-instance-identifier $(terraform output -raw mysql_endpoint | cut -d ":" -f1) --query "DBInstances[0].ReplicationSourceIdentifier"
   ```

2. **DocumentDB Replication**:
   ```bash
   aws docdb describe-db-clusters --db-cluster-identifier $(terraform output -raw mongodb_endpoint | cut -d ":" -f1) --query "DBClusters[0].ReplicationSourceIdentifier"
   ```

## Security Best Practices

1. **Rotate Credentials Regularly**:
   - Update database passwords: `terraform apply -var="mysql_admin_password=NewPassword" -var="mongodb_admin_password=NewPassword"`

2. **Audit CloudFront and WAF logs**:
   - Enable CloudFront access logging
   - Review WAF logs in CloudWatch

3. **Restrict SSH Access**:
   - Update security groups to only allow your IP: `terraform apply -var="admin_ip_address=your-new-ip"`

## Security Notes

1. The database services are configured in private subnets, only accessible from the application servers
2. SSH access to EC2 instances is restricted to your specified IP address
3. All passwords are marked as sensitive in Terraform and not displayed in logs
4. HTTPS is enforced on both frontend and backend using Let's Encrypt certificates
5. Regular security updates are applied through configured cron jobs

## Disaster Recovery Procedures

### Failover to DR Region

In case of primary region failure:

1. **For Pilot-Light Mode**:
   - Launch EC2 instances in DR region
   - Promote database replicas to primary
   - Update DNS to point to new instances

2. **For Active-Passive Mode**:
   - Update Route53 records to point to DR infrastructure
   - Verify application is working correctly in DR region

### Failback to Primary Region

Once the primary region is restored:

1. Re-establish database replication from DR to Primary
2. Update Route53 records to point back to primary region
3. Verify application is working correctly in primary region

## Cost Optimization

To optimize costs for your AWS infrastructure:

1. *Right-size resources*: Start with the specified instance types and adjust based on actual usage

2. *Reserved Instances*: Consider purchasing reserved instances for EC2, RDS, and ElastiCache if you plan long-term usage

3. *Spot Instances*: For non-critical components, consider using spot instances

4. *AWS Cost Explorer*: Use to track and optimize expenses

5. **Pilot-Light vs Active-Passive**:
   - Pilot-Light: ~40-50% additional cost above base infrastructure
   - Active-Passive: ~80-100% additional cost above base infrastructure

6. **Reserved Instances**:
   - Consider Reserved Instances for long-term deployments
   - Can reduce EC2 and RDS costs by 30-60%

7. **CloudFront Optimization**:
   - Use appropriate price class based on your audience location
   - Configure caching policies to reduce origin requests
   

## Backup Strategy

For data protection:

1. *Database backups*: 
   - RDS MySQL has 7-day automatic backups enabled
   - DocumentDB has automated backups configured
   - Consider setting up additional AWS Backup jobs for critical data

2. *EC2 backups*:
   - Consider enabling AWS Backup for your EC2 instances
   - Implement application-level backups for your data

## Monitoring

For effective monitoring:

1. *CloudWatch*: Monitor metrics for all AWS resources
2. *CloudWatch Logs*: Centralize application and system logs
3. *CloudWatch Alarms*: Set up alerts for important thresholds

## Conclusion

You now have a complete robust, secure, and disaster-ready infrastructure setup for running your AdhereLive application on AWS. The configuration provides a secure and scalable environment with all the required components: frontend, backend, MySQL, MongoDB, and Redis.

The CloudFront integration provides enhanced security and performance, while the DR capabilities ensure business continuity even in the event of a regional outage.

For additional assistance, refer to the AWS documentation or contact your system administrator.