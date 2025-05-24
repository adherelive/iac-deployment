# modules/codebuild/main.tf - CodeBuild Module for GitHub Integration

# ECR Repositories
resource "aws_ecr_repository" "backend" {
  name                 = "${var.name_prefix}-be"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-backend-repo"
  })
}

resource "aws_ecr_repository" "frontend" {
  name                 = "${var.name_prefix}-fe"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-frontend-repo"
  })
}

# ECR Lifecycle Policies
resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "prod", "staging"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images older than 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "frontend" {
  repository = aws_ecr_repository.frontend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "prod", "staging"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images older than 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# CodeBuild Service Role
resource "aws_iam_role" "codebuild_role" {
  name = "${var.name_prefix}-${var.environment}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# CodeBuild Policy
resource "aws_iam_role_policy" "codebuild_policy" {
  role = aws_iam_role.codebuild_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetAuthorizationToken",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ]
        Resource = [
          "${aws_s3_bucket.codebuild_artifacts.arn}",
          "${aws_s3_bucket.codebuild_artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "*"
      }
    ]
  })
}

# S3 Bucket for CodeBuild artifacts
resource "aws_s3_bucket" "codebuild_artifacts" {
  bucket = "${var.name_prefix}-${var.environment}-codebuild-artifacts-${random_string.bucket_suffix.result}"

  tags = var.tags
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket_versioning" "codebuild_artifacts" {
  bucket = aws_s3_bucket.codebuild_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "codebuild_artifacts" {
  bucket = aws_s3_bucket.codebuild_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "codebuild_artifacts" {
  bucket = aws_s3_bucket.codebuild_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Secrets Manager for GitHub access
# resource "aws_secretsmanager_secret" "github_token" {
#   name                    = "${var.name_prefix}-${var.environment}-github-token"
#   description             = "GitHub personal access token for private repo access"
#   recovery_window_in_days = 7

#   tags = var.tags
# }

# resource "aws_secretsmanager_secret" "ssh_private_key" {
#   name                    = "${var.name_prefix}-${var.environment}-ssh-private-key"
#   description             = "SSH private key for GitHub access"
#   recovery_window_in_days = 7

#   tags = var.tags
# }

# CloudWatch Log Groups for CodeBuild
resource "aws_cloudwatch_log_group" "backend_build" {
  name              = "/aws/codebuild/${var.name_prefix}-${var.environment}-backend-build"
  retention_in_days = 14

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "frontend_build" {
  name              = "/aws/codebuild/${var.name_prefix}-${var.environment}-frontend-build"
  retention_in_days = 14

  tags = var.tags
}

# CodeBuild Project for Backend
resource "aws_codebuild_project" "backend" {
  name         = "${var.name_prefix}-${var.environment}-backend-build"
  description  = "Build project for AdhereLive backend"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }

    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = aws_ecr_repository.backend.name
    }

    environment_variable {
      name  = "IMAGE_TAG"
      value = var.image_tag
    }

    # environment_variable {
    #   name  = "GITHUB_TOKEN"
    #   value = aws_secretsmanager_secret.github_token.name
    #   type  = "SECRETS_MANAGER"
    # }
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.backend_build.name
    }
  }

  source {
    type            = "GITHUB"
    location        = var.backend_repo_url
    git_clone_depth = 1
    # Specify branch separately if needed
    #source_version = "akshay-gaurav-latest-changes"  # Branch name here
    # git_submodules_config {
    #   fetch_submodules = true
    # }

    # auth {
    #   type = "OAUTH"
    #   resource = "https://github.com/adherelive/adherelive-web.git"
    #   # Note: Uncomment if using SSH keys
    # }

    buildspec = "buildspec-backend.yml"
    
    auth {
      type     = "OAUTH"
      resource = var.codestar_connection_arn
    }
  }

  source_version = var.backend_branch

  tags = var.tags
}

# CodeBuild Project for Frontend
resource "aws_codebuild_project" "frontend" {
  name         = "${var.name_prefix}-${var.environment}-frontend-build"
  description  = "Build project for AdhereLive frontend"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }

    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = aws_ecr_repository.frontend.name
    }

    environment_variable {
      name  = "IMAGE_TAG"
      value = var.image_tag
    }

    # environment_variable {
    #   name  = "GITHUB_TOKEN"
    #   value = aws_secretsmanager_secret.github_token.name
    #   type  = "SECRETS_MANAGER"
    # }
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.frontend_build.name
    }
  }

  source {
    type            = "GITHUB"
    location        = var.frontend_repo_url
    git_clone_depth = 1
    # Specify branch separately if needed
    #source_version = "akshay-gaurav-latest-changes"  # Branch name here
    # git_submodules_config {
    #   fetch_submodules = true
    # }

    # auth {
    #   type = "OAUTH"
    #   resource = "https://github.com/adherelive/adherelive-fe.git"
    #   # Note: Uncomment if using SSH keys
    # }

    buildspec = "buildspec-frontend.yml"
    
    auth {
      type     = "OAUTH"
      resource = var.codestar_connection_arn
    }
  }

  source_version = var.frontend_branch

  tags = var.tags
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}