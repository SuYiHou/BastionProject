output "codebuild_project_name" {
  description = "Name of the CodeBuild project"
  value       = aws_codebuild_project.this.name
}

output "codedeploy_application_name" {
  description = "Name of the CodeDeploy application"
  value       = aws_codedeploy_app.this.name
}

output "codedeploy_deployment_group_name" {
  description = "Deployment group responsible for rolling out builds"
  value       = aws_codedeploy_deployment_group.this.deployment_group_name
}

output "artifact_bucket_name" {
  description = "S3 bucket used to store build artifacts"
  value       = try(aws_s3_bucket.artifacts[0].bucket, var.artifact_bucket_name)
}
