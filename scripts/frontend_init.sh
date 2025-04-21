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
    python3-certbot-nginx

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
systemctl enable docker
systemctl start docker

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

cd /app/frontend

# Pull latest code (assuming you have a repository)
# git pull

# Build Docker image (if needed)
# docker build -t adherelive-fe:latest .

# Start or restart services
docker-compose down
docker-compose up -d

echo "Frontend deployed successfully"
EOF

chmod +x /app/deploy.sh

# Add a cron job to check for updates and deploy
echo "0 3 * * * /app/deploy.sh > /app/deploy.log 2>&1" | crontab -

# Add a cron job to renew Let's Encrypt certificates
echo "0 2 * * * certbot renew --quiet" | crontab -

echo "Frontend server setup completed"