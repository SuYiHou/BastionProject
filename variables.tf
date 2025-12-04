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

variable "game_name" {
  type        = list(string)
  description = "All different game"
  default     = []
}

// -----------------------------------------------------------------------------
// microservices：描述 monorepo 中每个微服务的 ECR、CodeBuild、CodeDeploy 配置。
// key = 微服务标识（例如 auth、payment），value 是一个 map（结构见 README 或注释）。
// 必填字段：codebuild_source_type、codebuild_source_location；其余字段可按需覆盖。
// -----------------------------------------------------------------------------
variable "microservices" {
  type        = map(any)
  description = <<EOT
示例：
microservices = {
  auth = {
    ecr_repository_name      = "mycorp-dev-auth"
    ecr_image_tag_mutability = "IMMUTABLE"
    ecr_scan_on_push         = true

    codebuild_source_type     = "GITLAB"
    codebuild_source_location = "https://gitlab.com/org/auth.git"
    codebuild_buildspec       = "buildspec-auth.yml"
    codebuild_privileged_mode = true
    codebuild_environment_variables = {
      SERVICE_NAME = "auth"
    }
    codedeploy_auto_scaling_group_names = ["auth-asg"]
  }

  payment = {
    ...
  }
}
EOT
  default     = {}
}
