output "vpc_id" {
  description = "ID of the managed VPC"
  value       = module.network.vpc_id
}

output "bastion_public_ip" {
  description = "Public IP address of the bastion host"
  value       = module.bastion.instance_public_ip
}

output "bastion_private_ip" {
  description = "Private IP address of the bastion host"
  value       = module.bastion.instance_private_ip
}

output "bastion_security_group_id" {
  description = "Security group applied to the bastion host"
  value       = module.bastion.security_group_id
}

output "bastion_iam_role_name" {
  description = "IAM role attached to the bastion instance"
  value       = module.bastion.iam_role_name
}
