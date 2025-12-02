# IAM 模块示例清单

下面汇总了几个常见场景的 `module "iam"` 调用示例，便于快速复制粘贴后按需修改。场景从简单到复杂排列，你可以在现有 `main.tf` 之外的独立工作区/文件里引用这些示例，并逐步替换其中的占位符。

> **提示**：`inline_policy_statements` 是在你的 IAM 模块中新增的“声明式”写法，写 Action/Resource 即可；如果你更习惯直接提供 JSON，也可以沿用老的 `inline_policies` 字段。

## 1. Bastion + SSM 基础权限
```hcl
module "iam_bastion_example" {
  source = "./module/iam"

  name                    = "${var.name_prefix}-${var.environment}-bastion-role"
  environment             = var.environment
  component               = "bastion"
  assume_role_services    = ["ec2.amazonaws.com"]
  managed_policy_arns     = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
  create_instance_profile = true

  inline_policy_statements = {
    "restrict-describe" = [
      {
        sid       = "DescribeNetworking"
        actions   = ["ec2:DescribeInstances", "ec2:DescribeSubnets"]
        resources = ["*"]
      }
    ]
  }
}
```

## 2. EKS 控制面角色（最小权限）
```hcl
module "iam_eks_cluster_example" {
  source = "./module/iam"

  name                 = "${var.name_prefix}-${var.environment}-eks-cluster-role"
  environment          = var.environment
  component            = "eks-cluster"
  assume_role_services = ["eks.amazonaws.com"]

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_VPC_ResourceController"
  ]
}
```

## 3. EKS 节点组角色（可叠加 IRSA）
```hcl
module "iam_eks_node_example" {
  source = "./module/iam"

  name                 = "${var.name_prefix}-${var.environment}-eks-node-role"
  environment          = var.environment
  component            = "eks-node"
  assume_role_services = ["ec2.amazonaws.com"]

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ]

  inline_policy_statements = {
    "ssm-logs" = [
      {
        actions   = ["logs:PutLogEvents", "logs:CreateLogStream"]
        resources = [module.observability.application_log_group_arn]
      }
    ]
  }
}
```
> 若改用 IRSA，请给 K8s ServiceAccount 设置注解 `eks.amazonaws.com/role-arn = <module output>`，并把 `assume_role_services` 换成 `sts.amazonaws.com`。

## 4. 应用工作负载（IRSA 示例：Fluent Bit）
```hcl
module "iam_irsa_fluentbit" {
  source = "./module/iam"

  name                 = "${var.name_prefix}-${var.environment}-irsa-fluentbit"
  environment          = var.environment
  component            = "observability"
  assume_role_services = ["sts.amazonaws.com"]

  inline_policy_statements = {
    "cw-logs" = [
      {
        sid       = "WriteApplicationLogs"
        actions   = ["logs:PutLogEvents", "logs:CreateLogStream", "logs:DescribeLogStreams"]
        resources = [module.observability.application_log_group_arn]
      }
    ]
  }
}
```
配合 Kubernetes：
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: fluent-bit
  namespace: observability
  annotations:
    eks.amazonaws.com/role-arn: module.iam_irsa_fluentbit.role_arn
```

## 5. 只读审计角色
```hcl
module "iam_security_audit" {
  source = "./module/iam"

  name                 = "${var.name_prefix}-${var.environment}-security-audit"
  environment          = var.environment
  component            = "security"
  assume_role_arns     = ["arn:aws:iam::123456789012:root"] # 允许指定审计账号承担

  managed_policy_arns = ["arn:aws:iam::aws:policy/SecurityAudit"]
  inline_policy_statements = {
    "cw-read" = [
      {
        actions   = ["logs:GetLogEvents", "logs:DescribeLogGroups"]
        resources = ["*"]
      }
    ]
  }
}
```

---
把这些示例放在 `docs/` 文件夹不会影响 Terraform 主流程；需要使用某个示例时，可将对应 module 复制到实际工作目录并替换变量/ARN。这样既保持了最小 IAM 的思路，又有随手可用的模板。EOF
