# AWS IAM Permissions Guide for AdhereLive Infrastructure

## Required AWS Permissions for 'adherelive' User

Since your AWS user 'adherelive' doesn't have Admin permissions, you'll need to attach specific IAM policies and groups to enable Terraform to create the necessary infrastructure. Here are the required permissions:

## AWS Managed Policies to Attach

Add your 'adherelive' user to these AWS managed policy groups:

### 1. Core Infrastructure Policies
```
AmazonVPCFullAccess
AmazonEC2FullAccess
AmazonECS_FullAccess
ElasticLoadBalancingFullAccess
```

### 2. Database Policies
```
AmazonRDSFullAccess
AmazonDocDBFullAccess
```

### 3. DNS and SSL Policies
```
AmazonRoute53FullAccess
AWSCertificateManagerFullAccess
```

### 4. Monitoring and Logging
```
CloudWatchFullAccess
CloudWatchLogsFullAccess
```

### 5. IAM Permissions (Limited)
```
IAMReadOnlyAccess
```

## Custom IAM Policy for Additional Permissions

Create a custom policy called `AdhereLive-TerraformPolicy` with these permissions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "iam:CreateRole",
                "iam:DeleteRole",
                "iam:GetRole",
                "iam:ListRolePolicies",
                "iam:ListAttachedRolePolicies",
                "iam:ListInstanceProfilesForRole",
                "iam:PassRole",
                "iam:AttachRolePolicy",
                "iam:DetachRolePolicy",
                "iam:PutRolePolicy",
                "iam:DeleteRolePolicy",
                "iam:GetRolePolicy",
                "iam:CreateInstanceProfile",
                "iam:DeleteInstanceProfile",
                "iam:AddRoleToInstanceProfile",
                "iam:RemoveRoleFromInstanceProfile",
                "iam:GetInstanceProfile",
                "iam:TagRole",
                "iam:UntagRole"
            ],
            "Resource": [
                "arn:aws:iam::*:role/adherelive-*",
                "arn:aws:iam::*:instance-profile/adherelive-*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:CreateBucket",
                "s3:DeleteBucket",
                "s3:GetBucketVersioning",
                "s3:PutBucketVersioning",
                "s3:GetBucketEncryption",
                "s3:PutBucketEncryption",
                "s3:GetBucketPublicAccessBlock",
                "s3:PutBucketPublicAccessBlock",
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::adherelive-*",
                "arn:aws:s3:::adherelive-*/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "kms:CreateKey",
                "kms:CreateAlias",
                "kms:DeleteAlias",
                "kms:DescribeKey",
                "kms:GetKeyPolicy",
                "kms:GetKeyRotationStatus",
                "kms:ListAliases",
                "kms:ListResourceTags",
                "kms:PutKeyPolicy",
                "kms:TagResource",
                "kms:UntagResource"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:CreateSecret",
                "secretsmanager:DeleteSecret",
                "secretsmanager:DescribeSecret",
                "secretsmanager:GetSecretValue",
                "secretsmanager:PutSecretValue",
                "secretsmanager:UpdateSecret",
                "secretsmanager:TagResource",
                "secretsmanager:UntagResource"
            ],
            "Resource": "arn:aws:secretsmanager:*:*:secret:adherelive-*"
        }
    ]
}
```

## Steps to Configure Permissions

### Option 1: Using AWS Console

1. **Login to AWS Console** as an admin user
2. **Navigate to IAM** → Users → adherelive
3. **Add permissions** → Attach policies directly
4. **Search and attach** each of the managed policies listed above
5. **Create the custom policy**:
   - Go to IAM → Policies → Create Policy
   - Use JSON tab and paste the custom policy above
   - Name it `AdhereLive-TerraformPolicy`
   - Attach it to the adherelive user

### Option 2: Using AWS CLI

```bash
# Attach managed policies
aws iam attach-user-policy --user-name adherelive --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess
aws iam attach-user-policy --user-name adherelive --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
aws iam attach-user-policy --user-name adherelive --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess
aws iam attach-user-policy --user-name adherelive --policy-arn arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess
aws iam attach-user-policy --user-name adherelive --policy-arn arn:aws:iam::aws:policy/AmazonRDSFullAccess
aws iam attach-user-policy --user-name adherelive --policy-arn arn:aws:iam::aws:policy/AmazonDocDBFullAccess
aws iam attach-user-policy --user-name adherelive --policy-arn arn:aws:iam::aws:policy/AmazonRoute53FullAccess
aws iam attach-user-policy --user-name adherelive --policy-arn arn:aws:iam::aws:policy/AWSCertificateManagerFullAccess
aws iam attach-user-policy --user-name adherelive --policy-arn arn:aws:iam::aws:policy/CloudWatchFullAccess
aws iam attach-user-policy --user-name adherelive --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsFullAccess
aws iam attach-user-policy --user-name adherelive --policy-arn arn:aws:iam::aws:policy/IAMReadOnlyAccess

# Create and attach custom policy
aws iam create-policy --policy-name AdhereLive-TerraformPolicy --policy-document file://custom-policy.json
aws iam attach-user-policy --user-name adherelive --policy-arn arn:aws:iam::ACCOUNT-ID:policy/AdhereLive-TerraformPolicy
```

## Security Considerations

1. **Principle of Least Privilege**: These permissions are scoped to resources with the "adherelive-" prefix where possible
2. **Resource Restrictions**: IAM roles and S3 buckets are restricted to adherelive-named resources
3. **No Admin Access**: This setup avoids giving full administrative access
4. **Temporary Permissions**: Consider creating a separate deployment role that can be assumed when needed

## Validation

After configuring permissions, test with:

```bash
# Check current user permissions
aws sts get-caller-identity

# Test VPC permissions
aws ec2 describe-vpcs

# Test ECS permissions
aws ecs list-clusters

# Test RDS permissions
aws rds describe-db-instances
```

## Troubleshooting Common Permission Issues

### If you encounter "Access Denied" errors:

1. **Check the specific service** mentioned in the error
2. **Verify the resource naming** matches the pattern (adherelive-*)
3. **Ensure the region** is correct (ap-south-1)
4. **Check IAM role trust relationships** if the error mentions role assumption

### For DocumentDB specifically:
DocumentDB requires RDS permissions since it uses the same service model.

### For ECS task execution:
The ECS tasks will need to pull Docker images from ECR, so ensure your images are pushed to Amazon ECR or make them publicly accessible.

## Next Steps After Permission Setup

1. **Configure AWS CLI** with the adherelive user credentials
2. **Set up Terraform state backend** (optional but recommended)
3. **Run the deployment script** to test permissions
4. **Monitor CloudWatch** for any permission-related issues during deployment