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

# Install Node.js 16
curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
apt-get install -y nodejs

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
systemctl enable docker
systemctl start docker

# Create app directory
mkdir -p /app/backend
cd /app/backend

# Create environment file with connection strings
cat << EOF > .env
NODE_ENV=production
PORT=5000
MYSQL_HOST=${mysql_host}
MYSQL_USER=${mysql_user}
MYSQL_PASSWORD=${mysql_password}
MYSQL_DATABASE=${mysql_database}
MONGO_URI=${mongodb_host}
REDIS_HOST=${redis_host}
REDIS_PORT=6379
REDIS_PASSWORD=${redis_password}
EOF

# Create Docker Compose file for the backend
cat << EOF > docker-compose.yml
version: '3'
services:
  backend:
    image: adherelive-be:latest
    restart: always
    ports:
      - "5000:5000"
    volumes:
      - ./.env:/usr/src/app/.env
    environment:
      - NODE_ENV=production
EOF

# Setup Nginx as a reverse proxy
cat << EOF > /etc/nginx/sites-available/backend
server {
    listen 80;
    server_name api.${domain_name};

    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# Enable the site
ln -s /etc/nginx/sites-available/backend /etc/nginx/sites-enabled/

# Test nginx configuration
nginx -t

# Reload nginx
systemctl reload nginx

# Create a script to build and deploy the application
cat << 'EOF' > /app/deploy.sh
#!/bin/bash

cd /app/backend

# Pull latest code (assuming you have a repository)
# git pull

# Build Docker image (if needed)
# docker build -t adherelive-be:latest .

# Start or restart services
docker-compose down
docker-compose up -d

echo "Backend deployed successfully"
EOF

chmod +x /app/deploy.sh

# Add a cron job to check for updates and deploy
echo "0 3 * * * /app/deploy.sh > /app/deploy.log 2>&1" | crontab -

# Add a cron job to renew Let's Encrypt certificates
echo "0 2 * * * certbot renew --quiet" | crontab -

echo "Backend server setup completed"