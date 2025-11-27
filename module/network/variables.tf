# 资源命名前缀，比如 platform-dev，后续会组合成 ${name}-vpc 之类的名字
variable "name" {
  type        = string
  description = "Base name used for tagging and naming network resources"
}

# 当前环境，用于标签（dev/prod 等）
variable "environment" {
  type        = string
  description = "Environment identifier for tagging"
}

# VPC 主网段，建议预留足够空间切子网
variable "vpc_cidr" {
  type        = string
  description = "CIDR block assigned to the VPC"
}

# 给 EKS 或其他服务打标签用，方便它们识别哪些子网可用
variable "cluster_name" {
  type        = string
  description = "Cluster name used in subnet tags for Kubernetes integrations"
}

# 额外的自定义标签，按需传入
variable "tags" {
  type        = map(string)
  description = "Additional tags to merge onto every resource"
  default     = {}
}
