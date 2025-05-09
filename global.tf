# Add DynamoDB Global Tables for session management
resource "aws_dynamodb_table" "sessions" {
  name           = "${var.prefix}-sessions"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "session_id"
  
  attribute {
    name = "session_id"
    type = "S"
  }
  
  replica {
    region_name = var.secondary_region
  }
  
  tags = {
    Name = "${var.prefix}-sessions"
  }
}

# Create S3 bucket for static assets with replication
resource "aws_s3_bucket" "static_assets" {
  bucket = "${var.prefix}-static-assets-${random_string.unique_suffix.result}"
  
  tags = {
    Name = "${var.prefix}-static-assets"
  }
}

resource "aws_s3_bucket" "dr_static_assets" {
  provider = aws.dr_region
  bucket   = "${var.prefix}-dr-static-assets-${random_string.unique_suffix.result}"
  
  tags = {
    Name = "${var.prefix}-dr-static-assets"
  }
}

# IAM role for S3 replication
resource "aws_iam_role" "replication" {
  name = "${var.prefix}-s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for S3 replication
resource "aws_iam_policy" "replication" {
  name = "${var.prefix}-s3-replication-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.static_assets.arn
        ]
      },
      {
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Effect = "Allow"
        Resource = [
          "${aws_s3_bucket.static_assets.arn}/*"
        ]
      },
      {
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Effect = "Allow"
        Resource = "${aws_s3_bucket.dr_static_assets.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "replication" {
  role       = aws_iam_role.replication.name
  policy_arn = aws_iam_policy.replication.arn
}

resource "aws_s3_bucket_replication_configuration" "static_assets_replication" {
  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.static_assets.id

  rule {
    id     = "assets-replication"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.dr_static_assets.arn
      storage_class = "STANDARD"
    }
  }
}