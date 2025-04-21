#!/bin/bash
# SSH Key deployment script 
# This script should be run after the infrastructure is deployed
# Usage: ./ssh_key_setup.sh backend.example.com frontend.example.com ~/.ssh/github_key

if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <backend-server-ip> <frontend-server-ip> <path-to-private-key>"
    exit 1
fi

BACKEND_SERVER=$1
FRONTEND_SERVER=$2
PRIVATE_KEY_PATH=$3
USERNAME=${4:-azureuser}

# Ensure the private key exists
if [ ! -f "$PRIVATE_KEY_PATH" ]; then
    echo "Private key not found at $PRIVATE_KEY_PATH"
    exit 1
fi

# Function to deploy SSH key to a server
deploy_key() {
    local server=$1
    echo "Deploying SSH key to $server..."
    
    # Copy the private key to the server
    scp -o StrictHostKeyChecking=no "$PRIVATE_KEY_PATH" ${USERNAME}@${server}:/home/${USERNAME}/.ssh/id_rsa
    
    # Set the correct permissions
    ssh -o StrictHostKeyChecking=no ${USERNAME}@${server} "chmod 600 /home/${USERNAME}/.ssh/id_rsa"
    
    # Test GitHub SSH connection
    ssh -o StrictHostKeyChecking=no ${USERNAME}@${server} "ssh -T -o StrictHostKeyChecking=no git@github.com || true"
    
    # Run the deployment script
    ssh -o StrictHostKeyChecking=no ${USERNAME}@${server} "sudo /app/deploy.sh"
    
    echo "Deployment to $server completed."
}

# Deploy keys to both servers
deploy_key "$BACKEND_SERVER"
deploy_key "$FRONTEND_SERVER"

echo "SSH key deployment completed successfully."