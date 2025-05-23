# Docker to ECS Migration Guide

## Adapting Your Current Docker Setup for AWS ECS

Based on your current `docker-stack.yml` and deployment script, here's how to adapt your containers for ECS:

## Key Changes from Docker Swarm to ECS

### 1. Remove Docker Swarm Specific Configurations

**Current (Docker Swarm):**
```yaml
deploy:
  replicas: 1
  restart_policy:
    condition: on-failure
  update_config:
    parallelism: 1
    delay: 10s
```

**ECS Equivalent (Handled by Terraform):**
- Replicas → `desired_count` in ECS service
- Restart policy → ECS service auto-restart
- Update config → ECS deployment configuration

### 2. Environment Variables and Secrets

**Current approach with files:**
```yaml
env_file:
  - .env
secrets:
  - mysql_root_password
  - mysql_user_password
  - mongodb_password
```

**ECS approach (in Terraform):**
```hcl
environment = [
  {
    name  = "NODE_ENV"
    value = "production"
  },
  {
    name  = "MYSQL_HOST"
    value = var.mysql_endpoint
  }
]

# For secrets, use AWS Secrets Manager or Parameter Store
secrets = [
  {
    name      = "MYSQL_PASSWORD"
    valueFrom = aws_secretsmanager_secret.mysql_password.arn
  }
]
```

### 3. Networking Changes

**Current (Bridge network):**
```yaml
networks:
  - al_ntwrk
```

**ECS (VPC networking):**
- Each task gets its own ENI
- Security groups control access
- No need for exposed ports in private subnets

### 4. Volume Mounting

**Current:**
```yaml
volumes:
  - ./.env:/user/src/app/.env
```

**ECS alternatives:**
- Use environment variables instead of mounted files
- Use EFS for persistent file storage if needed
- Use S3 for configuration files

## Updated Dockerfile Recommendations

### Backend Dockerfile for ECS
```dockerfile
# DockerfileECS for backend
FROM node:18-alpine

WORKDIR /usr/src/app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy application code
COPY . .

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Change ownership
RUN chown -R nodejs:nodejs /usr/src/app
USER nodejs

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node healthcheck.js || exit 1

EXPOSE 5000

CMD ["npm", "start"]
```

### Frontend Dockerfile for ECS
```dockerfile
# DockerfileECS for frontend
FROM node:18-alpine as builder

WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine

# Copy custom nginx config
COPY nginx.conf /etc/nginx/nginx.conf

# Copy built app
COPY --from=builder /app/build /usr/share/nginx/html

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/ || exit 1

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

## Application Code Changes

### 1. Health Check Endpoints

Add health check endpoints to your backend:

```javascript
// healthcheck.js for backend
const http = require('http');

const options = {
  host: 'localhost',
  port: process.env.PORT || 5000,
  path: '/health',
  timeout: 2000
};

const request = http.request(options, (res) => {
  console.log(`STATUS: ${res.statusCode}`);
  if (res.statusCode === 200) {
    process.exit(0);
  } else {
    process.exit(1);
  }
});

request.on('error', function(err) {
  console.log('ERROR:', err);
  process.exit(1);
});

request.end();
```

```javascript
// Add to your Express app
app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});
```

### 2. Environment Variable Updates

Update your backend to use AWS-provided connection strings:

```javascript
// Database configuration for ECS
const dbConfig = {
  mysql: {
    host: process.env.MYSQL_HOST,
    port: process.env.MYSQL_PORT || 3306,
    database: process.env.MYSQL_DATABASE,
    user: process.env.MYSQL_USER,
    password: process.env.MYSQL_PASSWORD
  },
  mongodb: {
    uri: process.env.MONGO_URI || 
         `mongodb://${process.env.MONGODB_USERNAME}:${process.env.MONGODB_PASSWORD}@${process.env.MONGODB_HOST}:27017/${process.env.MONGODB_DATABASE}?authSource=admin&ssl=true`
  }
};
```

### 3. Logging Configuration

Update logging for CloudWatch:

```javascript
// Use structured logging for CloudWatch
const winston = require('winston');

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console()
  ]
});

// Example usage
logger.info('Application started', { 
  port: process.env.PORT,
  environment: process.env.NODE_ENV 
});
```

## Build Script for ECS Images

Update your build script to create ECS-compatible images:

```bash
#!/bin/bash
# build-ecs-images.sh

MODE=$1
BRANCH=$2
AWS_REGION="ap-south-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

if [ -z "$MODE" ] || [ -z "$BRANCH" ]; then
  echo "Usage: $0 dev|prod git-branch-name"
  exit 1
fi

# Function to build and push image
build_and_push() {
  local service=$1
  local dockerfile=$2
  
  echo "Building $service for ECS..."
  
  cd adherelive-$service
  git checkout $BRANCH
  git pull origin $BRANCH
  
  # Copy ECS-specific Dockerfile
  cp ../docker/$dockerfile Dockerfile
  
  # Build image
  docker build -t adherelive-$service:$MODE .
  
  # Tag for ECR
  ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/adherelive-$service"
  docker tag adherelive-$service:$MODE $ECR_URI:$MODE
  docker tag adherelive-$service:$MODE $ECR_URI:latest
  
  # Login to ECR
  aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin $ECR_URI
  
  # Push to ECR
  docker push $ECR_URI:$MODE
  docker push $ECR_URI:latest
  
  echo "Successfully pushed $ECR_URI:$MODE"
  cd ..
}

# Build both services
build_and_push "be" "DockerfileECS-backend"
build_and_push "fe" "DockerfileECS-frontend"

echo "All images built and pushed successfully!"
echo "Update terraform.tfvars with:"
echo "backend_image  = \"$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/adherelive-be:$MODE\""
echo "frontend_image = \"$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/adherelive-fe:$MODE\""
```

## Environment Variables Mapping

Map your current environment variables to ECS:

```bash
# Current .env structure
NODE_ENV=production
MYSQL_HOST=mysql
MYSQL_DATABASE=adhere
MYSQL_USER=user
MYSQL_PASSWORD=password
MONGO_URI=mongodb://mongouser:password@mongodb:27017/adhere?authSource=admin

# ECS equivalent (handled by Terraform)
NODE_ENV=production
MYSQL_HOST=adherelive-prod-mysql.xxxxx.ap-south-1.rds.amazonaws.com
MYSQL_DATABASE=adhere
MYSQL_USER=user
MYSQL_PASSWORD=<from-terraform-tfvars>
MONGO_URI=mongodb://mongouser:password@adherelive-prod-docdb.cluster-xxxxx.docdb.ap-south-1.amazonaws.com:27017/adhere?authSource=admin&ssl=true
```

## Testing Your ECS Migration

### 1. Local Testing with ECS-Compatible Setup

```bash
# Test locally with similar environment
docker run -d \
  -e NODE_ENV=production \
  -e MYSQL_HOST=localhost \
  -e MYSQL_DATABASE=adhere \
  -p 5000:5000 \
  adherelive-be:prod

# Test health endpoint
curl http://localhost:5000/health
```

### 2. ECS Deployment Testing

```bash
# Check ECS service status
aws ecs describe-services \
  --cluster adherelive-prod-cluster \
  --services adherelive-prod-backend

# Check task health
aws ecs describe-tasks \
  --cluster adherelive-prod-cluster \
  --tasks $(aws ecs list-tasks --cluster adherelive-prod-cluster --service-name adherelive-prod-backend --query 'taskArns[0]' --output text)

# Check logs
aws logs get-log-events \
  --log-group-name /ecs/adherelive-prod-backend \
  --log-stream-name ecs/backend/$(date +%Y/%m/%d)
```

## Migration Checklist

- [ ] Create ECS-specific Dockerfiles
- [ ] Add health check endpoints to applications
- [ ] Update logging to use structured JSON format
- [ ] Remove file-based configuration dependencies
- [ ] Test images locally before deploying
- [ ] Set up ECR repositories
- [ ] Update environment variables for AWS services
- [ ] Configure SSL certificate validation for DocumentDB
- [ ] Test database connections with new endpoints
- [ ] Verify application functionality with ALB routing
- [ ] Set up monitoring and alerting
- [ ] Document the new deployment process

This migration approach maintains your application's functionality while leveraging AWS-managed services for better scalability and reliability.