---

# 🚀 Azure Infrastructure Setup Guide

You've completed the implementation of your infrastructure as code. Follow these final steps to get your environment up and running.

---

## ✅ Step 1: Prerequisites

1. **Install Azure CLI**  
   If you don’t have it already, [install the Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli).

2. **Install Terraform**  
   You’ll also need [Terraform installed](https://developer.hashicorp.com/terraform/downloads) on your machine.

3. **Log in to Azure**  
   Open your terminal and run:
   ```bash
   az login
   ```
   This will authenticate your Azure account.

---

## 🔧 Step 2: Configure Deployment Variables

1. **Generate an SSH Key**  
   Run the following command to create a key pair:
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/github_adherelive
   ```
   This creates:
   - Private key: `~/.ssh/github_adherelive`
   - Public key: `~/.ssh/github_adherelive.pub`

2. **Add Public Key to GitHub Repositories**  
   - Go to the settings of your `adherelive-fe` and `adherelive-be` repositories.
   - Add the contents of `~/.ssh/github_adherelive.pub` as a **Deploy Key**.
   - Enable write access if needed (not required for this setup).

3. **Update `terraform.tfvars`**  
   After running the deployment script, edit the generated `azure/terraform.tfvars` file:
   ```hcl
   ssh_public_key = "~/.ssh/github_adherelive.pub"
   my_ip_address  = "1.2.3.4/32"  # Replace with your actual public IP
   ```

---

## 🔐 Step 3: Populate Azure Key Vault with Secrets

The deployment will create an Azure Key Vault. Populate it with your actual secrets:

1. **GitHub Private Key**
   ```bash
   az keyvault secret set \
     --vault-name <your-key-vault-name> \
     --name "be-GITHUB-SSH-PRIVATE-KEY" \
     --file ~/.ssh/github_adherelive
   ```

2. **MongoDB Atlas Connection String**
   ```bash
   az keyvault secret set \
     --vault-name <your-key-vault-name> \
     --name "be-MONGO-DB-URI" \
     --value "<your-mongodb-connection-string>"
   ```

3. **Other Secrets**  
   Add additional secrets (e.g., Twilio, SendGrid, Algolia) using the Azure CLI or Portal:
   ```bash
   az keyvault secret set \
     --vault-name <your-key-vault-name> \
     --name "be-TWILIO-ACCOUNT-SID" \
     --value "<your-secret-value>"
   ```

---

## 🚀 Step 4: Deploy the Infrastructure

Use the `deploy.sh` script located at the root of your repository:

1. **Plan the Deployment**
   ```bash
   ./deploy.sh azure plan
   ```
   This previews the resources that will be created.

2. **Apply the Deployment**
   ```bash
   ./deploy.sh azure apply
   ```
   This executes the deployment. It may take a few minutes.

---

## 🌐 Step 5: Access Your Application

After deployment, the script will output the public IPs and FQDNs:

- **Frontend:**  
  `http://<frontend-fqdn>`

- **Backend:**  
  `http://<backend-fqdn>:5000`

To use a custom domain, update your DNS records to point to the public IPs of your VMs.

---
