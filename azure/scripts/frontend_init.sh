#!/bin/bash

# Update and install dependencies
apt-get update
apt-get upgrade -y
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common \
    nginx \
    certbot \
    python3-certbot-nginx \
    git

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
systemctl enable docker
systemctl start docker

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Setup SSH key for the azureuser
mkdir -p /home/${admin_username}/.ssh
touch /home/${admin_username}/.ssh/id_rsa
chmod 600 /home/${admin_username}/.ssh/id_rsa
# Note: You'll need to manually add the private key after deployment or use a key vault

# Add GitHub to known hosts
mkdir -p /home/${admin_username}/.ssh
ssh-keyscan -t rsa github.com >> /home/${admin_username}/.ssh/known_hosts
chown -R ${admin_username}:${admin_username} /home/${admin_username}/.ssh

# Create app directory
mkdir -p /app/frontend
cd /app/frontend

# Create environment file for the frontend
cat << EOF > .env
REACT_APP_API_URL=${backend_url}
EOF

# Create Docker Compose file for the frontend
cat << EOF > docker-compose.yml
version: '3'
services:
  frontend:
    image: adherelive-fe:latest
    restart: always
    ports:
      - "3000:80"
    environment:
      - NODE_ENV=production
EOF

# Configure Nginx to serve the frontend application
cat << EOF > /etc/nginx/sites-available/frontend
server {
    listen 80;
    server_name ${domain_name} www.${domain_name};

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# Enable the site
ln -s /etc/nginx/sites-available/frontend /etc/nginx/sites-enabled/

# Test nginx configuration
nginx -t

# Reload nginx
systemctl reload nginx

# Set up Let's Encrypt SSL for the domain
certbot --nginx -d ${domain_name} -d www.${domain_name} --non-interactive --agree-tos -m ${email} --redirect

# Create a script to build and deploy the application
cat << 'EOF' > /app/deploy.sh
#!/bin/bash

# Clone or pull the latest code
if [ ! -d "/app/frontend/repo" ]; then
    # First time setup - clone the repo
    git clone git@github.com:adherelive/adherelive-fe.git /app/frontend/repo
    cd /app/frontend/repo
else
    # Repository exists - pull the latest changes
    cd /app/frontend/repo
    git pull
fi

# Get the current commit hash for labeling
COMMIT_HASH=$(git rev-parse --short HEAD)

# Build the Docker image
docker build -t adherelive-fe:latest -f Dockerfile-fe --build-arg COMMIT_HASH=$COMMIT_HASH .

# Go back to the app directory
cd /app/frontend

# Start or restart services
docker-compose down
docker-compose up -d

echo "Frontend deployed successfully with commit: $COMMIT_HASH"
EOF

chmod +x /app/deploy.sh

# Add a cron job to check for updates and deploy
echo "0 3 * * * /app/deploy.sh > /app/deploy.log 2>&1" | crontab -

# Add a cron job to renew Let's Encrypt certificates
echo "0 2 * * * certbot renew --quiet" | crontab -

echo "Frontend server setup completed"