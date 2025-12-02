output "cluster_name" {
  description = "Provisioned EKS cluster name"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority" {
  description = "Base64 encoded certificate authority data"
  value       = try(aws_eks_cluster.this.certificate_authority[0].data, null)
}

output "node_group_name" {
  description = "Managed node group name"
  value       = aws_eks_node_group.default.node_group_name
}

output "node_group_arn" {
  description = "ARN of the managed node group"
  value       = aws_eks_node_group.default.arn
}
