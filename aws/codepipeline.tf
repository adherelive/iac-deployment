# codepipeline.tf - CI/CD Pipeline for AdhereLive

# --- S3 Bucket for Pipeline Logging ---
resource "aws_s3_bucket" "codepipeline_log_bucket" {
  bucket = "${local.name_prefix}-${local.environment}-codepipeline-logs-${data.aws_caller_identity.current.account_id}"

  tags = local.common_tags
}

# --- S3 Bucket for Pipeline Artifacts ---
resource "aws_s3_bucket" "codepipeline_artifacts" {
  bucket = "${local.name_prefix}-${local.environment}-codepipeline-artifacts-${data.aws_caller_identity.current.account_id}"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  versioning {
    enabled = true
  }

  logging {
    target_bucket = aws_s3_bucket.codepipeline_log_bucket.id
    target_prefix = "log/"
  }

  tags = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "codepipeline_artifacts" {
  bucket = aws_s3_bucket.codepipeline_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# --- IAM Role for CodePipeline ---
resource "aws_iam_role" "codepipeline_role" {
  name = "${local.name_prefix}-${local.environment}-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "${local.name_prefix}-${local.environment}-codepipeline-policy"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObjectAcl",
          "s3:PutObject"
        ],
        Resource = [
          aws_s3_bucket.codepipeline_artifacts.arn,
          "${aws_s3_bucket.codepipeline_artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "codestar-connections:UseConnection"
        ],
        Resource = var.codestar_connection_arn
      },
      {
        Effect = "Allow",
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:UpdateService",
          "ecs:RegisterTaskDefinition"
        ],
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = module.ecs.task_role_arn
      }
    ]
  })
}

# --- AWS CodePipeline ---
resource "aws_codepipeline" "main" {
  name     = "${local.name_prefix}-${local.environment}-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_artifacts.bucket
    type     = "S3"
  }

  # --- Source Stage ---
  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceOutput"]

      configuration = {
        ConnectionArn    = var.codestar_connection_arn
        FullRepositoryId = "${var.github_owner}/${var.github_repo}"
        BranchName       = var.github_branch
      }
    }
  }

  # --- Build Stage ---
  stage {
    name = "Build"
    action {
      name             = "Build_Backend"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceOutput"]
      output_artifacts = ["BackendBuildOutput"]

      configuration = {
        ProjectName = module.codebuild.backend_codebuild_project_name
      }
    }
    action {
      name             = "Build_Frontend"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceOutput"]
      output_artifacts = ["FrontendBuildOutput"]

      configuration = {
        ProjectName = module.codebuild.frontend_codebuild_project_name
      }
    }
  }

  # --- Deploy Stage ---
  stage {
    name = "Deploy"
    action {
      name            = "Deploy_Backend"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["BackendBuildOutput"]

      configuration = {
        ClusterName = module.ecs.cluster_name
        ServiceName = module.ecs.backend_service_name
        FileName    = "imagedefinitions.json"
      }
    }
    action {
      name            = "Deploy_Frontend"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["FrontendBuildOutput"]

      configuration = {
        ClusterName = module.ecs.cluster_name
        ServiceName = module.ecs.frontend_service_name
        FileName    = "imagedefinitions.json"
      }
    }
  }
}
