## 1. Bastion + SSM 基础权限

module "iam_bastion_example" {
  source = "./module/iam"

  name                    = "${var.name_prefix}-${var.environment}-bastion-role"
  environment             = var.environment
  component               = "bastion"
  assume_role_services = ["ec2.amazonaws.com"]
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
  create_instance_profile = true

  inline_policy_statements = {
    "restrict-describe" = [
      {
        sid = "DescribeNetworking"
        actions = ["ec2:DescribeInstances", "ec2:DescribeSubnets"]
        resources = ["*"]
      }
    ]
  }
}


## 2. EKS 控制面角色（最小权限）

module "iam_eks_cluster_example" {
  source = "./module/iam"

  name        = "${var.name_prefix}-${var.environment}-eks-cluster-role"
  environment = var.environment
  component   = "eks-cluster"
  assume_role_services = ["eks.amazonaws.com"]

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_VPC_ResourceController"
  ]
}


## 3. EKS 节点组角色（可叠加 IRSA）

module "iam_eks_node_example" {
  source = "./module/iam"

  name        = "${var.name_prefix}-${var.environment}-eks-node-role"
  environment = var.environment
  component   = "eks-node"
  assume_role_services = ["ec2.amazonaws.com"]

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ]

  inline_policy_statements = {
    "ssm-logs" = [
      {
        actions = ["logs:PutLogEvents", "logs:CreateLogStream"]
        resources = [module.observability.application_log_group_arn]
      }
    ]
  }
}

# 若改用 IRSA，请给 K8s ServiceAccount 设置注解 `eks.amazonaws.com/role-arn = <module output>`，并把 `assume_role_services` 换成 `sts.amazonaws.com`。

## 4. 应用工作负载（IRSA 示例：Fluent Bit）

module "iam_irsa_fluentbit" {
  source = "./module/iam"

  name        = "${var.name_prefix}-${var.environment}-irsa-fluentbit"
  environment = var.environment
  component   = "observability"
  assume_role_services = ["sts.amazonaws.com"]

  inline_policy_statements = {
    "cw-logs" = [
      {
        sid = "WriteApplicationLogs"
        actions = ["logs:PutLogEvents", "logs:CreateLogStream", "logs:DescribeLogStreams"]
        resources = [module.observability.application_log_group_arn]
      }
    ]
  }
}

# 配合 Kubernetes：
# yaml
# apiVersion: v1
# kind: ServiceAccount
# metadata:
# name: fluent-bit
# namespace: observability
# annotations:
# eks.amazonaws.com/role-arn: module.iam_irsa_fluentbit.role_arn
#

## 5. 只读审计角色

module "iam_security_audit" {
  source = "./module/iam"

  name        = "${var.name_prefix}-${var.environment}-security-audit"
  environment = var.environment
  component   = "security"
  assume_role_arns = ["arn:aws:iam::123456789012:root"] # 允许指定审计账号承担

  managed_policy_arns = ["arn:aws:iam::aws:policy/SecurityAudit"]
  inline_policy_statements = {
    "cw-read" = [
      {
        actions = ["logs:GetLogEvents", "logs:DescribeLogGroups"]
        resources = ["*"]
      }
    ]
  }
}

# > 角色用途
#
# - Bastion/SSM 角色 (docs/iam-samples.md:14-35)
#   - 对象：运行跳板机 EC2 的实例 profile。
#   - 用途：允许该实例被 Session Manager 登录，并执行少量 Describe* 查询帮助排障，不授予创建/删除权限，避免跳板机被滥用去操作生产资源。
# - EKS 控制面角色 (docs/iam-samples.md:38-55)
#   - 对象：由 AWS 托管的 EKS 控制平面服务承担。
#   - 用途：控制面需要这些权限来创建/管理 ENI、安全组、ELB 等网络资源，实现 Kubernetes API Server 的自动伸缩与健康检查。运维人员不会直接用它。
# - EKS 节点组角色 (docs/iam-samples.md:58-84)
#   - 对象：EKS 托管节点（EC2 实例）的实例 profile。
#   - 用途：工作节点需要读取/写入 CNI 相关信息、从 ECR 拉镜像、向 CloudWatch 打日志。业务 Pod 不应依赖此角色；它只是提供节点级别的基础能力。
# - IRSA 工作负载角色（Fluent Bit 示例，docs/iam-samples.md:87-111）
#   - 对象：Kubernetes ServiceAccount（例如 Fluent Bit DaemonSet）。
#   - 用途：通过 IRSA 将最小权限授予单个工作负载，如写入应用日志到 CloudWatch，避免所有 Pod 共用节点角色，降低横向移动风险。
# - 只读审计角色 (docs/iam-samples.md:114-137)
#   - 对象：安全/审计账号或自动化工具（SIEM、Config 检查脚本）。
#   - 用途：允许跨账号承担该角色，查看所有资源配置、读取日志，但不具备修改能力，满足合规和安全事件调查需要。