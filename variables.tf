// -----------------------------------------------------------------------------
// 根模块变量说明：为初学者准备的集中入口，统一在这里调整 VPC、Bastion、EKS 的全部参数。
// 建议：结合 terraform.tfvars 示例文件查看真实取值，或在 CI/CD 中使用 TF_VAR_ 环境变量。
// -----------------------------------------------------------------------------
variable "region" {
  type        = string
  description = "AWS region"
}

variable "environment" {
  type        = string
  description = "Environment name, e.g. dev / prod"
}

variable "name_prefix" {
  type        = string
  description = "Name prefix for bastion resources"
  default     = "mycorp-dev"
}

variable "terraform_dev_profile" {
  type        = string
  description = "AWS connection credential"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the managed VPC"
  default     = "172.31.0.0/16"
}

variable "eks_cluster_name" {
  type        = string
  description = "Cluster name used when tagging subnets"
  default     = "game-test-env"
}

variable "ssh_allowed_cidr" {
  type        = list(string)
  description = "CIDR list allowed to SSH"
  default     = []
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "key_name" {
  type        = string
  description = "Existing EC2 KeyPair name for SSH"
}

variable "ami_id" {
  type        = string
  description = "AMI ID for bastion instance (e.g. Amazon Linux 2023)"
}

variable "enable_ssm" {
  type        = bool
  description = "Whether to allow SSM Session Manager access"
}

variable "root_volume_size" {
  type        = number
  description = "Size (GiB) of the root EBS volume"
}

variable "force_detach_policies" {
  type        = bool
  description = "Whether to forcibly detach policies before destroying the role"
}

variable "create_instance_profile" {
  type        = bool
  description = "If true, create an instance profile tied to the role"
}

variable "instance_profile_name" {
  type        = string
  description = "Optional custom instance profile name"
}

variable "eks_cluster_version" {
  type        = string
  description = "Desired Kubernetes version for the EKS control plane"
  default     = "1.29"
}

variable "eks_cluster_enabled_log_types" {
  type        = list(string)
  description = "Control plane log types to enable (api, audit, authenticator, controllerManager, scheduler)"
  default     = []
}

variable "eks_cluster_endpoint_private_access" {
  type        = bool
  description = "Expose the Kubernetes API over the VPC private subnets"
  default     = true
}

variable "eks_cluster_endpoint_public_access" {
  type        = bool
  description = "Expose the Kubernetes API via public internet"
  default     = false
}

variable "eks_node_instance_types" {
  type        = list(string)
  description = "Allowed instance types for the default managed node group"
  default     = ["t3.medium"]
}

variable "eks_node_desired_size" {
  type        = number
  description = "Desired worker node count"
  default     = 2
}

variable "eks_node_min_size" {
  type        = number
  description = "Minimum worker node count"
  default     = 1
}

variable "eks_node_max_size" {
  type        = number
  description = "Maximum worker node count"
  default     = 3
}

variable "eks_node_disk_size" {
  type        = number
  description = "EBS volume size (GiB) for each worker"
  default     = 50
}

variable "eks_node_capacity_type" {
  type        = string
  description = "ON_DEMAND or SPOT"
  default     = "ON_DEMAND"
}

variable "eks_node_labels" {
  type        = map(string)
  description = "Kubernetes labels attached to the managed node group"
  default     = {}
}

variable "eks_node_tags" {
  type        = map(string)
  description = "AWS tags merged onto the managed node group"
  default     = {}
}

variable "eks_node_max_unavailable" {
  type        = number
  description = "How many nodes can be unavailable during rolling updates"
  default     = 1
}

variable "observability_log_retention_days" {
  type        = number
  description = "Retention days for the EKS control plane log group"
  default     = 30
}

variable "observability_app_log_retention_days" {
  type        = number
  description = "Retention days for the shared application log group"
  default     = 30
}

variable "observability_create_archive_bucket" {
  type        = bool
  description = "Whether to create a centralized S3 bucket for long-term log storage"
  default     = true
}

variable "observability_archive_bucket_name" {
  type        = string
  description = "Optional custom name for the log archive bucket"
  default     = null
}

variable "observability_archive_transition_days" {
  type        = number
  description = "How many days before archived logs transition to Glacier"
  default     = 90
}

variable "observability_archive_expiration_days" {
  type        = number
  description = "How many days before archived logs are deleted"
  default     = 365
}

variable "observability_archive_force_destroy" {
  type        = bool
  description = "Allow Terraform to delete the archive bucket even if it contains objects"
  default     = false
}

// -----------------------------------------------------------------------------
// CI/CD 相关变量：用于驱动 CodeBuild + CodeDeploy 模块。全部字段都有默认值或示例，
// 你只需根据仓库类型、部署目标填写对应值即可。
// -----------------------------------------------------------------------------
variable "cicd_codebuild_source_type" {
  type        = string
  description = "CodeBuild 源类型 (GITHUB / CODECOMMIT / S3 等)"
}

variable "cicd_codebuild_source_location" {
  type        = string
  description = "源码位置：例如 GitHub repo HTTPS URL 或 CodeCommit 仓库名"
}

variable "cicd_codebuild_buildspec" {
  type        = string
  description = "buildspec 文件路径"
  default     = "buildspec.yml"
}

variable "cicd_codebuild_image" {
  type        = string
  description = "构建容器镜像"
  default     = "aws/codebuild/standard:6.0"
}

variable "cicd_codebuild_compute_type" {
  type        = string
  description = "构建机规格"
  default     = "BUILD_GENERAL1_SMALL"
}

variable "cicd_codebuild_privileged_mode" {
  type        = bool
  description = "是否启用 Docker in Docker（构建镜像时需要）"
  default     = false
}

variable "cicd_codebuild_environment_variables" {
  type        = map(string)
  description = "构建环境变量"
  default     = {}
}

variable "cicd_codebuild_artifact_path" {
  type        = string
  description = "输出产物在 S3 桶内的路径前缀"
  default     = "build"
}

variable "cicd_codebuild_log_retention_days" {
  type        = number
  description = "CodeBuild 日志保留天数"
  default     = 30
}

variable "cicd_codebuild_timeout_minutes" {
  type        = number
  description = "构建超时时长"
  default     = 30
}

variable "cicd_codebuild_git_clone_depth" {
  type        = number
  description = "Git shallow clone 深度"
  default     = 1
}

variable "cicd_codebuild_ecr_access" {
  type        = bool
  description = "构建任务是否需要访问 ECR（推/拉镜像）"
  default     = false
}

variable "cicd_codebuild_extra_policy_statements" {
  type = list(object({
    sid       = optional(string)
    effect    = optional(string, "Allow")
    actions   = list(string)
    resources = list(string)
  }))
  description = "需要额外授予 CodeBuild 的 IAM 权限"
  default     = []
}

variable "cicd_create_artifact_bucket" {
  type        = bool
  description = "是否让模块自动创建产物桶"
  default     = true
}

variable "cicd_artifact_bucket_name" {
  type        = string
  description = "自定义 artifact 桶名（不填则按前缀自动生成）"
  default     = null
}

variable "cicd_artifact_bucket_force_destroy" {
  type        = bool
  description = "销毁时是否允许强删非空桶"
  default     = false
}

variable "cicd_existing_artifact_bucket_arn" {
  type        = string
  description = "如果已有 artifact 桶，直接填 ARN 并把 cicd_create_artifact_bucket 设为 false"
  default     = null
}

variable "cicd_codedeploy_deployment_config" {
  type        = string
  description = "CodeDeploy 部署策略"
  default     = "CodeDeployDefault.AllAtOnce"
}

variable "cicd_codedeploy_auto_scaling_group_names" {
  type        = list(string)
  description = "需要部署的 AutoScaling Group 列表"
  default     = []
}

variable "cicd_codedeploy_target_tag_key" {
  type        = string
  description = "若无 ASG，可通过 EC2 标签筛选，提供 Tag Key"
  default     = null
}

variable "cicd_codedeploy_target_tag_value" {
  type        = string
  description = "搭配 Key 使用的 Tag 值"
  default     = null
}

// -----------------------------------------------------------------------------
// ECR 仓库参数：为了让 CodeBuild/业务统一推送镜像，建议在 Terraform 中集中创建仓库。
// -----------------------------------------------------------------------------
variable "ecr_repository_name" {
  type        = string
  description = "ECR 仓库名称"
  default     = null
}

variable "ecr_image_tag_mutability" {
  type        = string
  description = "镜像 tag 是否允许覆盖 (MUTABLE/IMMUTABLE)"
  default     = "MUTABLE"
}

variable "ecr_scan_on_push" {
  type        = bool
  description = "推送后是否自动扫描镜像安全性"
  default     = true
}

variable "ecr_encryption_type" {
  type        = string
  description = "AES256 或 KMS"
  default     = "AES256"
}

variable "ecr_kms_key_arn" {
  type        = string
  description = "若选择 KMS 加密，请提供密钥 ARN"
  default     = null
}

variable "ecr_lifecycle_policy" {
  type        = string
  description = "Lifecycle Policy JSON，用于清理旧镜像"
  default     = null
}

variable "ecr_repository_policy" {
  type        = string
  description = "Repository policy JSON，控制哪些账号/角色可访问"
  default     = null
}
