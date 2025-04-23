# AWS Deployment Guide for AdhereLive

This guide walks you through deploying your AdhereLive application stack on AWS using Terraform.

## Prerequisites

Before you begin, make sure you have the following installed on your local machine:

1. *AWS CLI*: [Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
2. *Terraform*: [Installation Guide](https://learn.hashicorp.com/tutorials/terraform/install-cli)
3. *SSH Key Pair*: Generate using `ssh-keygen -t rsa -b 4096`

## Setup Steps

### 1. Clone the Repository

```bash
git clone https://github.com/your-repo/adherelive-aws-infrastructure.git
cd adherelive-aws-infrastructure
```

### 2. Configure Your AWS Credentials

Ensure you have AWS credentials configured:

```bash
aws configure
```

Enter your AWS Access Key ID, Secret Access Key, default region, and output format when prompted.

### 3. Configure Your Deployment

1. Create a copy of the example variables file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

2. Edit `terraform.tfvars` with your specific values:
   - Update `region` to your preferred AWS region
   - Update `ami_id` to a valid Ubuntu AMI for your selected region
   - Set `admin_ip_address` to your IP address for SSH security
   - Set strong passwords for `mysql_admin_password` and `mongodb_admin_password`
   - Update `domain_name` with your actual domain
   - Add your email address for Let's Encrypt notifications

### 4. Initialize Terraform

```bash
terraform init
```

### 5. Plan the Deployment

```bash
terraform plan -out=tfplan
```

Review the plan to make sure it's creating the resources you expect.

### 6. Apply the Terraform Configuration

```bash
terraform apply tfplan
```

This will create all the necessary resources in AWS. The process may take 15-20 minutes.

### 7. Configure DNS

After deployment completes, Terraform will output your frontend and backend IP addresses:

1. If your domain is registered elsewhere, add NS records pointing to the AWS Route 53 nameservers
2. If needed, configure additional DNS records through the AWS Console

### 8. Deploy Your Application Code

Once the infrastructure is ready, you need to set up SSH access to GitHub repositories on both VMs:

1. *Prepare your GitHub SSH key*:
   - Make sure you have an SSH key that has access to the AdhereLive GitHub repositories
   - If you don't have one, create it and add it to your GitHub account

2. *Deploy the SSH key to your servers*:
   - Use the provided script to deploy your GitHub SSH key to both servers:

```bash
# Get the IPs from Terraform output
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

3. *Verify deployment*:
   - Check that the applications are running by accessing:
     - Frontend: https://your-domain.com
     - Backend API: https://api.your-domain.com

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

### Updating the Application

To update your application:

1. Push new code to your GitHub repositories
2. SSH into the VMs and run the deploy script:

```bash
ssh ubuntu@YOUR_VM_IP "sudo /app/deploy.sh"
```

### Modifying Infrastructure

If you need to modify the infrastructure:

1. Update the Terraform files
2. Run `terraform plan` to see the changes
3. Apply the changes with `terraform apply`

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

## Security Notes

1. The database services are configured in private subnets, only accessible from the application servers
2. SSH access to EC2 instances is restricted to your specified IP address
3. All passwords are marked as sensitive in Terraform and not displayed in logs
4. HTTPS is enforced on both frontend and backend using Let's Encrypt certificates
5. Regular security updates are applied through configured cron jobs

## Cost Optimization

To optimize costs for your AWS infrastructure:

1. *Right-size resources*: Start with the specified instance types and adjust based on actual usage
2. *Reserved Instances*: Consider purchasing reserved instances for EC2, RDS, and ElastiCache if you plan long-term usage
3. *Spot Instances*: For non-critical components, consider using spot instances
4. *AWS Cost Explorer*: Use to track and optimize expenses

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

You now have a complete infrastructure setup for running your AdhereLive application on AWS. The configuration provides a secure and scalable environment with all the required components: frontend, backend, MySQL, MongoDB, and Redis.

For additional assistance, refer to the AWS documentation or contact your system administrator.