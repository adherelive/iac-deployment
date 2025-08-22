Here's a summary of what we need to deploy the AdhereLive application on Azure using Terraform:

## Our Infrastructure as Code Solution

Created a complete Terraform solution that includes:

1. *GitHub Repository Integration*:
   - Add configuration to clone the repositories:
     - `git@github.com:adherelive/adherelive-web.git` (backend)
     - `git@github.com:adherelive/adherelive-fe.git` (frontend)

2. *Docker Build Process*:
   - Updated deployment scripts to build Docker images using provided Dockerfile(s)
   - Added logic to capture the commit hash for image tagging

3. *SSH Key Management*:
   - Created a dedicated script (`ssh_key_setup.sh`) to deploy the GitHub SSH keys to the servers
   - This allows secure cloning of private repositories

4. *Automated Deployment*:
   - Deployment scripts now handle the entire process:
     - Cloning/updating the repositories
     - Building Docker images
     - Starting containers with the right environment variables

5. *Virtual Network & Security Groups*: 
   - Separate subnets for the frontend, backend, and databases
   - Properly configured NSGs to control traffic

6. *Managed Databases*:
   - Azure MySQL instance for the relational data
   - Azure Cosmos DB with MongoDB API
   - Azure Redis Cache for caching needs

7. *Compute Resources*:
   - Two virtual machines for frontend and backend applications
   - Ubuntu-based with automatic updates and Docker preinstalled

8. *Networking*:
   - Public IP addresses with DNS names
   - Domain configuration with Azure DNS
   - HTTPS setup using Let's Encrypt certificates

9. *Initialization Scripts*:
   - Bash scripts to configure both VMs on startup
   - Nginx setup as a reverse proxy
   - SSL certificate automation

## How to Deploy

To deploy this infrastructure from the local laptop:

1. Install the Azure CLI and Terraform on the local machine

2. *Set Up Your Infrastructure*: 
   - Run the Terraform scripts as described in the deployment guide

3. *Deploy SSH Keys*:
   - After infrastructure creation, use the `ssh_key_setup.sh` script to deploy your GitHub SSH key
   - This enables the VMs to authenticate with GitHub

4. *Trigger Deployment*:
   - The deployment script will automatically:
     - Clone the repositories
     - Build the Docker images using the Dockerfiles you provided
     - Start the services with the proper configuration

5. *Ongoing Updates*:
   - When you want to update your application, just SSH into the server and run:
     ```
     sudo /app/deploy.sh
     ```
   - This will pull the latest code, rebuild the image, and restart the service

6. Copy `terraform.tfvars.example` to `terraform.tfvars` and update with our values
7. Run `terraform init` to initialize
8. Run `terraform plan` to verify everything looks good
9. Run `terraform apply` to create the infrastructure

The deployment guide provides detailed instructions for each step, including what to do after the infrastructure is created.

## Docker Image Deployment

After the infrastructure is ready, we'll need to:

1. Build the Docker images for both frontend and backend
2. Push them to a registry (Docker Hub or set up Azure Container Registry)
3. Update the Docker Compose files on the VMs to use the images
4. Run the deployment scripts

The initialization scripts created install all necessary dependencies and set up continuous deployment through cron jobs, which will also handle SSL certificate renewal.
