# Deployment Guide for AdhereLive on Azure

This guide walks you through deploying your AdhereLive application stack on Azure using Terraform.

## Prerequisites

Before you begin, make sure you have the following installed on your local machine:

1. *Azure CLI*: [Installation Guide](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
2. *Terraform*: [Installation Guide](https://learn.hashicorp.com/tutorials/terraform/install-cli)
3. *SSH Key Pair*: Generate using `ssh-keygen -t rsa -b 4096`

## Setup Steps

### 1. Clone the Repository

```bash
git clone https://github.com/your-repo/adherelive-azure-infrastructure.git
cd adherelive-azure-infrastructure
```

### 2. Configure Your Deployment

1. Create a copy of the example variables file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

2. Edit `terraform.tfvars` with your specific values:
   - Update `admin_ip_address` with your IP address for SSH security
   - Set a strong `mysql_admin_password`
   - Update `domain_name` with your actual domain
   - Add your email address for Let's Encrypt notifications

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Login to Azure

```bash
az login
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

This will create all the necessary resources in Azure. The process may take 15-20 minutes.

### 7. Configure DNS

After deployment completes, Terraform will output your frontend and backend IP addresses and FQDNs. You'll need to configure your domain's DNS settings:

1. If your domain is registered elsewhere, add NS records pointing to the Azure nameservers listed in the Azure DNS Zone that was created
2. If needed, configure additional DNS records through the Azure portal

### 8. Deploy Your Application Code

Once the infrastructure is ready, you need to set up SSH access to GitHub repositories:

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

- *Virtual Network* with separate subnets for frontend, backend, and databases
- *Network Security Groups* with configured rules for each component
- *Azure MySQL* database service
- *Azure Cosmos DB* with MongoDB API
- *Azure Redis Cache*
- *Virtual Machines* for frontend and backend applications
- *Public IP addresses* with DNS names
- *Azure DNS Zone* for domain management

## SSL Configuration

Let's Encrypt certificates are automatically set up for your domain. The certificates will auto-renew through a configured cron job.

## Maintenance

### Updating the Application

To update your application:

1. Push new Docker images to your registry
2. SSH into the VMs and run the deploy script:

```bash
ssh azureuser@YOUR_VM_IP "sudo /app/deploy.sh"
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
  ssh azureuser@YOUR_VM_IP "sudo docker logs -f container_name"
  ```

- *Nginx Logs*: Check web server logs for issues
  ```bash
  ssh azureuser@YOUR_VM_IP "sudo cat /var/log/nginx/error.log"
  ```

### SSH Access Issues

If you can't SSH into the VMs:
1. Verify your IP is allowed in the Network Security Group
2. Check that you're using the correct SSH key
3. Confirm the VM is running in the Azure portal

## Security Notes

1. The MySQL and MongoDB services are configured with private network access only, accessible from the backend subnet
2. SSH access to VMs is restricted to your specified IP address
3. All passwords and secrets are marked as sensitive in Terraform and not displayed in logs
4. HTTPS is enforced on the frontend using Let's Encrypt certificates
5. Regular security updates are applied through configured cron jobs

## Cost Optimization

To optimize costs for your Azure infrastructure:

1. *Right-size resources*: Start with the specified VM sizes and adjust based on actual usage
2. *Scale databases*: Begin with the basic tiers and scale up as needed
3. *Reserved Instances*: Consider purchasing reserved instances for VMs if you plan long-term usage
4. *Monitor usage*: Set up Azure Cost Management to track and optimize expenses

## Backup Strategy

While the deployment doesn't include backups by default, consider:

1. *Database backups*: 
   - MySQL has 7-day automatic backups enabled
   - Set up additional Cosmos DB backup policies through the Azure portal

2. *VM backups*:
   - Consider enabling Azure Backup for your VMs
   - Implement application-level backups for your data

## Monitoring

For effective monitoring:

1. *Azure Monitor*: Enable for all resources to track performance metrics
2. *Log Analytics*: Configure to centralize logs from all components
3. *Application Insights*: Add to your backend code for detailed application monitoring

## Conclusion

You now have a complete infrastructure setup for running your AdhereLive application on Azure. The configuration provides a secure and scalable environment with all the required components: frontend, backend, MySQL, MongoDB, and Redis.

For additional assistance, refer to the Azure documentation or contact your system administrator.