#!/bin/bash
set -ex

# Variables passed from Terraform
KEY_VAULT_NAME="${key_vault_name}"
GIT_REPO_URL="${git_repo_url}"
APP_NAME="${app_name}" # "frontend" or "backend"
APP_PORT="${app_port}" # 80 for fe, 5000 for be
GITHUB_SSH_KEY_SECRET_NAME="be-GITHUB_SSH_PRIVATE_KEY" # The name of the secret in Key Vault

# Install dependencies
apt-get update
apt-get install -y docker.io jq curl

# Add azure-cli
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Add current user to docker group
usermod -aG docker azureuser

# Login to Azure using Managed Identity
az login --identity

# Get SSH private key from Key Vault
mkdir -p /home/azureuser/.ssh
az keyvault secret show --name $GITHUB_SSH_KEY_SECRET_NAME --vault-name $KEY_VAULT_NAME --query "value" -o tsv > /home/azureuser/.ssh/id_rsa
chown -R azureuser:azureuser /home/azureuser/.ssh
chmod 600 /home/azureuser/.ssh/id_rsa

# Add github.com to known_hosts
ssh-keyscan -t rsa github.com >> /home/azureuser/.ssh/known_hosts

# Clone the repository
cd /home/azureuser
su - azureuser -c "git clone $GIT_REPO_URL app"

# Fetch secrets from Key Vault and create .env file
cd /home/azureuser/app
touch .env

secrets=$(az keyvault secret list --vault-name $KEY_VAULT_NAME --query "[?starts_with(id, 'https://{KEY_VAULT_NAME}.vault.azure.net/secrets/${app_name}-')].id" --output tsv)
for secret_id in $secrets; do
    secret_name=$(echo $secret_id | awk -F'/' '{print $NF}')
    secret_value=$(az keyvault secret show --id $secret_id --query "value" -o tsv)

    # remove prefix from secret name for the .env file
    env_var_name=$(echo $secret_name | sed "s/^${app_name}-//")
    echo "$env_var_name=$secret_value" >> .env
done

# Special handling for nginx.conf for frontend
if [ "$APP_NAME" == "frontend" ]; then
    cat << EOF > /home/azureuser/app/nginx.conf
${nginx_conf_content}
EOF
fi

# Build and run Docker container
cd /home/azureuser/app
docker build -t $APP_NAME .

# Expose correct port
if [ "$APP_NAME" == "frontend" ]; then
    docker run -d -p 80:80 --restart=always $APP_NAME
else
    docker run -d -p 5000:5000 --restart=always $APP_NAME
fi
