// Basic identity details for the bastion instance so callers can reference it directly.
output "instance_id" {
  description = "ID of the bastion EC2 instance"
  value       = aws_instance.this.id
}

output "instance_public_ip" {
  description = "Public IPv4 address of the bastion"
  value       = aws_instance.this.public_ip
}

output "instance_private_ip" {
  description = "Private IPv4 address of the bastion"
  value       = aws_instance.this.private_ip
}

output "security_group_id" {
  description = "Security group attached to the bastion"
  value       = var.bastion_sg_id
}

// IAM integration data, useful when granting the bastion more permissions externally.
output "iam_role_name" {
  description = "IAM role associated with the bastion"
  value       = aws_iam_role.this.name
}
