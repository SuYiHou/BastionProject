output "security_group_ids" {
  description = "Return all ids of security groups by name"
  value       = {for k, sg in aws_security_group.this : k => sg.id}
}