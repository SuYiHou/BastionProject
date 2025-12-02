output "control_plane_log_group_name" {
  description = "CloudWatch log group that stores EKS control plane logs"
  value       = aws_cloudwatch_log_group.eks_control_plane.name
}

output "application_log_group_name" {
  description = "CloudWatch log group that workloads can stream application logs into"
  value       = aws_cloudwatch_log_group.eks_application.name
}

output "archive_bucket_name" {
  description = "Central archive bucket for long-term log retention (null if disabled)"
  value       = try(aws_s3_bucket.archive[0].bucket, null)
}
