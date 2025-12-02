// -----------------------------------------------------------------------------
// EKS 模块：包装最常用的资源——EKS 控制面 + 1 个托管节点组。
// - 通过变量把 VPC/子网/安全组/IAM 角色作为依赖注入，复用外部模块输出；
// - 集中收敛与伸缩、日志、访问方式等选项，方便初学者理解每个开关的作用。
// -----------------------------------------------------------------------------
locals {
  base_tags = merge({
    Environment = var.environment,
    Component   = "eks",
    ManagedBy   = "terraform"
  }, var.tags)
}

// 控制面：只负责管理 API Server（工作节点另有 node group），
// 这里需要传入 Role ARN + 可用的子网/安全组，同时可配置是否开启公网/私网访问。
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = var.cluster_role_arn

  enabled_cluster_log_types = var.cluster_enabled_log_types

  vpc_config {
    subnet_ids              = var.cluster_subnet_ids
    security_group_ids      = var.cluster_security_group_ids
    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access  = var.cluster_endpoint_public_access
  }

  tags = merge(local.base_tags, {
    Name = var.cluster_name
  })
}

// 托管节点组：AWS 自动管理节点生命周期和升级；
// 变量允许自定义实例规格、容量类型（ON_DEMAND/ SPOT）、磁盘、标签、伸缩策略等。
resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = var.node_group_name
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.node_group_subnet_ids

  instance_types = var.node_group_instance_types
  capacity_type  = var.node_group_capacity_type
  disk_size      = var.node_group_disk_size
  labels         = var.node_group_labels

  scaling_config {
    desired_size = var.node_group_desired_size
    min_size     = var.node_group_min_size
    max_size     = var.node_group_max_size
  }

  update_config {
    max_unavailable = var.node_group_max_unavailable
  }

  tags = merge(local.base_tags, var.node_group_tags, {
    Name = var.node_group_name
  })
}
