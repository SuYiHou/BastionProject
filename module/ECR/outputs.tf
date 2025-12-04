output "repository_name" {
  description = "ECR repository name"
  value       = aws_ecr_repository.this.name
}

output "repository_arn" {
  description = "ARN of the repository"
  value       = aws_ecr_repository.this.arn
}

output "repository_url" {
  description = "Full URL used for Docker login/push"
  value       = aws_ecr_repository.this.repository_url
}
