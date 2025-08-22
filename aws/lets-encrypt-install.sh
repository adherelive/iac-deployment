#!/bin/bash
# lets-encrypt-setup.sh - Alternative SSL setup using Let's Encrypt

# This script sets up Let's Encrypt SSL certificates for your domain
# Run this AFTER your domain is pointing to the ALB

set -e

DOMAIN="test.adhere.live"
EMAIL="admin@adhere.live"
AWS_REGION="ap-south-1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

# Get ALB DNS name from Terraform
get_alb_info() {
    log "Getting ALB information from Terraform..."
    
    ALB_DNS_NAME=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")
    
    if [[ -z "$ALB_DNS_NAME" ]]; then
        error "Could not get ALB DNS name from Terraform. Deploy infrastructure first."
    fi
    
    log "ALB DNS Name: $ALB_DNS_NAME"
}

# Verify domain is pointing to ALB
verify_domain() {
    log "Verifying domain configuration..."
    
    RESOLVED_IP=$(dig +short $DOMAIN @8.8.8.8 | tail -n1)
    ALB_IP=$(dig +short $ALB_DNS_NAME @8.8.8.8 | tail -n1)
    
    if [[ "$RESOLVED_IP" == "$ALB_IP" ]]; then
        success "Domain $DOMAIN is correctly pointing to ALB"
    else
        warn "Domain may not be fully propagated yet"
        echo "Domain resolves to: $RESOLVED_IP"
        echo "ALB resolves to: $ALB_IP"
        echo ""
        read -p "Continue anyway? (yes/no): " continue_anyway
        if [[ "$continue_anyway" != "yes" ]]; then
            exit 0
        fi
    fi
}

# Create temporary EC2 instance for certificate generation
create_certbot_instance() {
    log "Creating temporary EC2 instance for certificate generation..."
    
    # Get VPC and subnet info
    VPC_ID=$(terraform output -raw vpc_id)
    PUBLIC_SUBNET_ID=$(terraform output -json public_subnet_ids | jq -r '.[0]')
    
    # Create security group for certbot
    CERTBOT_SG_ID=$(aws ec2 create-security-group \
        --group-name "adherelive-certbot-temp" \
        --description "Temporary security group for Let's Encrypt certificate generation" \
        --vpc-id "$VPC_ID" \
        --region "$AWS_REGION" \
        --query 'GroupId' \
        --output text)
    
    # Allow HTTP and SSH access
    aws ec2 authorize-security-group-ingress \
        --group-id "$CERTBOT_SG_ID" \
        --protocol tcp \
        --port 80 \
        --cidr 0.0.0.0/0 \
        --region "$AWS_REGION"
    
    aws ec2 authorize-security-group-ingress \
        --group-id "$CERTBOT_SG_ID" \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0 \
        --region "$AWS_REGION"
    
    # Launch EC2 instance
    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id ami-0da59f1af71ea4ad2 \
        --count 1 \
        --instance-type t3.micro \
        --security-group-ids "$CERTBOT_SG_ID" \
        --subnet-id "$PUBLIC_SUBNET_ID" \
        --associate-public-ip-address \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=adherelive-certbot-temp}]" \
        --user-data file://certbot-userdata.sh \
        --region "$AWS_REGION" \
        --query 'Instances[0].InstanceId' \
        --output text)
    
    log "Created EC2 instance: $INSTANCE_ID"
    log "Waiting for instance to be ready..."
    
    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$AWS_REGION"
    
    # Get public IP
    PUBLIC_IP=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --region "$AWS_REGION" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)
    
    log "Instance ready. Public IP: $PUBLIC_IP"
    echo "$INSTANCE_ID $CERTBOT_SG_ID $PUBLIC_IP"
}

# Create user data script for certbot
create_userdata_script() {
    cat > certbot-userdata.sh << 'EOF'
#!/bin/bash
yum update -y
yum install -y python3 python3-pip
pip3 install certbot

# Create simple HTTP server for domain validation
mkdir -p /tmp/letsencrypt-validation
cd /tmp/letsencrypt-validation

# Start simple HTTP server
python3 -m http.server 80 &

# Wait a bit for server to start
sleep 10

# Generate certificate (this will be done manually via SSH)
echo "Certbot installation complete"
EOF
}

# Generate Let's Encrypt certificate
generate_certificate() {
    local instance_info=$1
    local instance_id=$(echo $instance_info | cut -d' ' -f1)
    local public_ip=$(echo $instance_info | cut -d' ' -f3)
    
    log "Generating Let's Encrypt certificate..."
    log "You'll need to SSH into the instance to complete certificate generation"
    
    echo ""
    echo "SSH Command:"
    echo "ssh -i your-key.pem ec2-user@$public_ip"
    echo ""
    echo "Once connected, run:"
    echo "sudo certbot certonly --standalone -d $DOMAIN --email $EMAIL --agree-tos --non-interactive"
    echo ""
    echo "After certificate generation, download the files:"
    echo "sudo cat /etc/letsencrypt/live/$DOMAIN/fullchain.pem"
    echo "sudo cat /etc/letsencrypt/live/$DOMAIN/privkey.pem"
    echo ""
    
    read -p "Press Enter after you've downloaded the certificate files..."
}

# Upload certificate to ACM
upload_to_acm() {
    log "Upload the downloaded certificate to ACM..."
    
    echo "Use this command to upload to ACM:"
    echo ""
    echo "aws acm import-certificate \\"
    echo "    --certificate fileb://fullchain.pem \\"
    echo "    --private-key fileb://privkey.pem \\"
    echo "    --region $AWS_REGION"
    echo ""
    
    read -p "Enter the ACM certificate ARN after upload: " CERT_ARN
    
    if [[ -n "$CERT_ARN" ]]; then
        # Update terraform.tfvars with certificate ARN
        echo "" >> terraform.tfvars
        echo "# Let's Encrypt Certificate ARN" >> terraform.tfvars
        echo "ssl_certificate_arn = \"$CERT_ARN\"" >> terraform.tfvars
        
        success "Certificate ARN added to terraform.tfvars"
    fi
}

# Cleanup temporary resources
cleanup() {
    local instance_info=$1
    local instance_id=$(echo $instance_info | cut -d' ' -f1)
    local sg_id=$(echo $instance_info | cut -d' ' -f2)
    
    log "Cleaning up temporary resources..."
    
    # Terminate instance
    aws ec2 terminate-instances --instance-ids "$instance_id" --region "$AWS_REGION"
    
    # Wait for termination
    aws ec2 wait instance-terminated --instance-ids "$instance_id" --region "$AWS_REGION"
    
    # Delete security group
    aws ec2 delete-security-group --group-id "$sg_id" --region "$AWS_REGION"
    
    # Clean up local files
    rm -f certbot-userdata.sh
    
    success "Cleanup completed"
}

# Main execution
main() {
    log "Let's Encrypt SSL Setup for AdhereLive"
    echo ""
    
    get_alb_info
    verify_domain
    
    create_userdata_script
    instance_info=$(create_certbot_instance)
    
    generate_certificate "$instance_info"
    upload_to_acm
    
    cleanup "$instance_info"
    
    echo ""
    success "Let's Encrypt setup completed!"
    warn "Remember to run 'terraform apply' to update the load balancer with the new certificate"
}

# Run main function
main "$@"