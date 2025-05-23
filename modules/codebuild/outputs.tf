# modules/codebuild/outputs.tf
output "backend_ecr_repository_url" {
  description = "Backend ECR repository URL"
  value       = aws_ecr_repository.backend.repository_url
}

output "frontend_ecr_repository_url" {
  description = "Frontend ECR repository URL"
  value       = aws_ecr_repository.frontend.repository_url
}

output "backend_codebuild_project_name" {
  description = "Backend CodeBuild project name"
  value       = aws_codebuild_project.backend.name
}

output "frontend_codebuild_project_name" {
  description = "Frontend CodeBuild project name"
  value       = aws_codebuild_project.frontend.name
}

output "github_token_secret_arn" {
  description = "GitHub token secret ARN"
  value       = aws_secretsmanager_secret.github_token.arn
}

output "ssh_private_key_secret_arn" {
  description = "SSH private key secret ARN"
  value       = aws_secretsmanager_secret.ssh_private_key.arn
}