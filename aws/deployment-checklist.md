# AdhereLive AWS Deployment Checklist

## Pre-Deployment Requirements ✅

### AWS Account Setup
- [ ] AWS account with 'adherelive' user created
- [ ] AWS CLI installed and configured
- [ ] Required IAM permissions attached (see permissions guide)
- [ ] Domain 'adhere.live' registered and managed in Route53
- [ ] AWS region ap-south-1 (Mumbai) selected

### Local Development Environment
- [ ] Terraform installed (v1.0+)
- [ ] Docker installed and running
- [ ] Git repositories accessible (adherelive-be, adherelive-fe)
- [ ] Current applications working locally

## Phase 1: Infrastructure Preparation ⚙️

### Directory Structure Setup
- [ ] Create `adherelive-infrastructure` directory
- [ ] Copy all Terraform files to correct locations
- [ ] Make deployment script executable (`chmod +x deploy-infrastructure.sh`)
- [ ] Verify all module files are in place

### Docker Image Preparation
- [ ] Create ECR repositories for backend and frontend
- [ ] Build ECS-compatible Docker images
- [ ] Add health check endpoints to applications
- [ ] Test images locally
- [ ] Push images to ECR
- [ ] Note ECR URIs for terraform.tfvars

### Terraform Configuration
- [ ] Run `./deploy-infrastructure.sh init`
- [ ] Review generated `terraform.tfvars`
- [ ] Update passwords with secure values
- [ ] Update ECR image URIs
- [ ] Configure scaling parameters for 100 users

## Phase 2: Modular Deployment Testing 🧪

### Network Foundation (Experiment 1)
- [ ] Comment out database and application modules in main.tf
- [ ] Run `./deploy-infrastructure.sh plan`
- [ ] Review VPC and security group plan
- [ ] Run `./deploy-infrastructure.sh apply`
- [ ] Verify VPC creation in AWS console
- [ ] Test connectivity between subnets

### Database Layer (Experiment 2)
- [ ] Uncomment RDS and DocumentDB modules
- [ ] Run `./deploy-infrastructure.sh plan`
- [ ] Review database configuration
- [ ] Run `./deploy-infrastructure.sh apply`
- [ ] Test database connectivity from local machine
- [ ] Verify backup and encryption settings

### Application Layer (Experiment 3)
- [ ] Uncomment ECS module
- [ ] Update image URIs in terraform.tfvars
- [ ] Run `./deploy-infrastructure.sh plan`
- [ ] Review ECS and ALB configuration
- [ ] Run `./deploy-infrastructure.sh apply`

## Phase 3: Complete Deployment 🚀

### SSL and DNS Configuration
- [ ] Verify ACM certificate is issued
- [ ] Confirm DNS records are created
- [ ] Test HTTPS endpoint: `https://test.adhere.live`
- [ ] Verify HTTP to HTTPS redirect

### Application Testing
- [ ] Test frontend accessibility
- [ ] Test backend API endpoints via `/api/*`
- [ ] Verify database connections work
- [ ] Check health endpoints return 200
- [ ] Test user registration/login flow

### Load Balancer and Auto Scaling
- [ ] Verify target groups are healthy
- [ ] Test load balancing between tasks
- [ ] Verify auto scaling triggers work
- [ ] Test application under moderate load

## Phase 4: Production Readiness 🔒

### Security Configuration
- [ ] Verify all services in private subnets (except ALB)
- [ ] Check security group rules are restrictive
- [ ] Confirm SSL/TLS encryption everywhere
- [ ] Review IAM roles have minimal permissions
- [ ] Enable VPC Flow Logs

### Monitoring and Alerting
- [ ] Verify CloudWatch logs are being generated
- [ ] Set up custom CloudWatch dashboards
- [ ] Configure CloudWatch alarms for key metrics
- [ ] Test Route53 health checks
- [ ] Set up SNS notifications for alerts

### Backup and Disaster Recovery
- [ ] Verify automated database backups are working
- [ ] Test database restoration process
- [ ] Enable Multi-AZ for RDS (production setting)
- [ ] Configure cross-region backup replication
- [ ] Document disaster recovery procedures

## Phase 5: Performance Optimization 📈

### Capacity Planning for 100 Users
- [ ] Monitor resource utilization under load
- [ ] Adjust ECS task sizing if needed
- [ ] Fine-tune auto scaling parameters
- [ ] Optimize database connections and queries
- [ ] Configure CloudFront CDN if needed

### Cost Optimization
- [ ] Review AWS Cost Explorer for current spend
- [ ] Set up billing alerts
- [ ] Consider Reserved Instances for RDS
- [ ] Implement resource scheduling for dev environments
- [ ] Enable detailed monitoring selectively

## Phase 6: Operational Procedures 🔧

### Deployment Process
- [ ] Document image build and deployment process
- [ ] Create rollback procedures
- [ ] Test blue-green deployment capability
- [ ] Set up CI/CD pipeline integration points
- [ ] Document emergency procedures

### Maintenance and Updates
- [ ] Schedule regular security updates
- [ ] Plan database maintenance windows
- [ ] Set up log rotation and cleanup
- [ ] Create backup testing schedule
- [ ] Document scaling procedures for growth

## Testing Scenarios 🧪

### Functional Testing
- [ ] User registration and authentication
- [ ] All API endpoints respond correctly
- [ ] Database CRUD operations work
- [ ] File uploads/downloads (if applicable)
- [ ] Email notifications (if applicable)

### Performance Testing
- [ ] Load test with 50 concurrent users
- [ ] Load test with 100 concurrent users
- [ ] Database performance under load
- [ ] Auto scaling behavior verification
- [ ] SSL handshake performance

### Disaster Recovery Testing
- [ ] Simulate AZ failure
- [ ] Test database failover
- [ ] Verify backup restoration
- [ ] Test DNS failover (if configured)
- [ ] Document recovery time objectives

## Troubleshooting Reference 🔍

### Common Issues and Solutions
- [ ] ECS tasks failing to start → Check logs and environment variables
- [ ] Health check failures → Verify security groups and application health endpoints
- [ ] SSL certificate issues → Check Route53 DNS validation
- [ ] Database connection timeouts → Verify security groups and connection strings
- [ ] High latency → Check ALB target group health and task distribution

### Monitoring Commands
```bash
# Check ECS service status
aws ecs describe-services --cluster adherelive-prod-cluster --services adherelive-prod-backend

# View recent logs
aws logs tail /ecs/adherelive-prod-backend --follow

# Check ALB target health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>

# Monitor auto scaling
aws application-autoscaling describe-scaling-activities --service-namespace ecs
```

## Success Criteria ✅

### Technical Success
- [ ] Application accessible via https://test.adhere.live
- [ ] All health checks passing
- [ ] Database connections stable
- [ ] Auto scaling working correctly
- [ ] Monitoring and alerting operational

### Performance Success
- [ ] Response time < 2 seconds for 95% of requests
- [ ] Supports 100 concurrent users without degradation
- [ ] Database queries optimized for expected load
- [ ] Auto scaling triggers within 5 minutes of threshold

### Operational Success
- [ ] Deployment process documented and tested
- [ ] Monitoring covers all critical components
- [ ] Backup and recovery procedures validated
- [ ] Team trained on operational procedures
- [ ] Cost within expected budget parameters

## Post-Deployment Actions 📋

### Immediate (First 24 Hours)
- [ ] Monitor application closely for any issues
- [ ] Verify all monitoring and alerting is working
- [ ] Test backup procedures
- [ ] Update documentation with any deployment notes

### Week 1
- [ ] Analyze performance metrics and optimize if needed
- [ ] Gather user feedback on application performance
- [ ] Fine-tune auto scaling parameters based on actual usage
- [ ] Review and adjust monitoring thresholds

### Month 1
- [ ] Review cost optimization opportunities
- [ ] Plan for additional features or scaling needs
- [ ] Conduct disaster recovery drill
- [ ] Update security configurations based on best practices

This checklist provides a systematic approach to deploying your infrastructure while allowing for experimentation and learning at each phase. Each checkmark represents a validated step in your AWS journey!