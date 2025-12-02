# ------------------------- 全局 / 基础设施形态 -------------------------
environment      = "dev"         # 用于拼接资源名称、标签、区分环境
name_prefix      = "mycorp"      # 全局名称前缀，确保多环境不冲突
vpc_cidr         = "10.0.0.0/16" # 自建 VPC 的网段
eks_cluster_name = "game-test"   # EKS 名称前缀（会再追加环境）
ssh_allowed_cidr = [
  "153.242.124.14/32" # 允许 SSH 的出口公网 IP（可按需追加多个）
]
terraform_dev_profile = "Terraform-dev"  # CLI/SDK 使用的 AWS Profile 名称
region                = "ap-southeast-2" # 目标区域

# ------------------------- Bastion / EC2 配置 -------------------------
instance_type           = "t3.medium"                       # Bastion 实例规格
key_name                = "Terraform-poc-key-zhaojiyu"      # 预先创建的 EC2 KeyPair 名称
ami_id                  = "ami-007e5a061b93ceb2f"           # OS 镜像 ID（建议选择最新 Amazon Linux）
root_volume_size        = 20                                # 根盘大小 (GiB)
enable_ssm              = true                              # 是否挂载 SSM 托管策略，便于 Systems Manager 登录
create_instance_profile = true                              # 是否让 iam 模块同步创建 Instance Profile
force_detach_policies   = true                              # 删除角色前是否先强制解绑策略
instance_profile_name   = "mycorp-dev-bastion-role-profile" # 可选：自定义 Instance Profile 名称

# ------------------------- EKS 控制面开关 -------------------------
eks_cluster_version                 = "1.29"           # Kubernetes 版本
eks_cluster_enabled_log_types       = ["api", "audit"] # 需要发送到 CloudWatch 的控制面日志
eks_cluster_endpoint_private_access = true             # 开启 VPC 内访问 API Server
eks_cluster_endpoint_public_access  = false            # 关闭公网 API（需要外部访问时改为 true）

# ------------------------- EKS 托管节点组 -------------------------
eks_node_instance_types = ["t3.medium"] # 单个节点组允许的实例类型列表（可放 2~3 个以提升调度成功率）
eks_node_desired_size   = 2             # 期望节点数
eks_node_min_size       = 1             # 自动伸缩的最小节点数
eks_node_max_size       = 3             # 自动伸缩的最大节点数
eks_node_disk_size      = 50            # 每个节点的根盘大小 (GiB)
eks_node_capacity_type  = "ON_DEMAND"   # 可选值：ON_DEMAND / SPOT
eks_node_labels = {
  role = "general" # 给 Kubernetes 节点打上 label，方便调度
}
eks_node_tags            = {} # 需要附加到节点组资源本身的 AWS Tag
eks_node_max_unavailable = 1  # 滚动升级时最多允许 1 台节点不可用
