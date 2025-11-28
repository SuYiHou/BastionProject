output "role_name" {
  description = "IAM role name"
  value       = aws_iam_role.this.name
}

output "role_arn" {
  description = "ARN of the IAM role"
  value       = aws_iam_role.this.arn
}

output "assume_role_policy" {
  description = "Rendered assume role policy JSON"
  value       = data.aws_iam_policy_document.assume_role.json
}

output "instance_profile_name" {
  description = "Name of the instance profile if one is created"
  value       = try(aws_iam_instance_profile.this[0].name, null)
}

output "instance_profile_arn" {
  description = "ARN of the optional instance profile"
  value       = try(aws_iam_instance_profile.this[0].arn, null)
}
