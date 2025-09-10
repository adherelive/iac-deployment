# modules/codebuild/main.tf - CodeBuild Module

# ECR Repositories
resource "aws_ecr_repository" "backend" {
  name                 = "${var.name_prefix}-be"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
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

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-frontend-repo"
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
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:GetObjectVersion"
        ],
        Resource = "arn:aws:s3:::*/*"
      }
    ]
  })
}

# CodeBuild Project for Backend
resource "aws_codebuild_project" "backend" {
  name         = "${var.name_prefix}-${var.environment}-backend-build"
  description  = "Build project for AdhereLive backend"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
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

    # The IMAGE_TAG will be the commit ID from the pipeline
    # environment_variable {
    #   name  = "IMAGE_TAG"
    #   value = var.image_tag
    # }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec-backend.yml"
  }

  tags = var.tags
}

# CodeBuild Project for Frontend
resource "aws_codebuild_project" "frontend" {
  name         = "${var.name_prefix}-${var.environment}-frontend-build"
  description  = "Build project for AdhereLive frontend"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
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

    # The IMAGE_TAG will be the commit ID from the pipeline
    # environment_variable {
    #   name  = "IMAGE_TAG"
    #   value = var.image_tag
    # }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec-frontend.yml"
  }

  tags = var.tags
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}