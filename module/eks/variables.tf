// ----------------------------- 通用参数 -----------------------------
variable "environment" {
  type        = string
  description = "Environment label (dev/prod/etc.) used for tagging"
}

variable "tags" {
  type        = map(string)
  description = "Optional extra tags merged on top of the defaults"
  default     = {}
}

// ----------------------------- 控制面参数 -----------------------------
variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
}

variable "cluster_version" {
  type        = string
  description = "Kubernetes version for the control plane"
}

variable "cluster_role_arn" {
  type        = string
  description = "IAM role ARN assumed by the EKS control plane"
}

variable "cluster_subnet_ids" {
  type        = list(string)
  description = "Subnets (typically private + public) associated with the control plane"

  validation {
    condition     = length(var.cluster_subnet_ids) >= 2
    error_message = "Provide at least two subnets so the control plane can run across AZs."
  }
}

variable "cluster_security_group_ids" {
  type        = list(string)
  description = "Security groups attached to the cluster network interfaces"

  validation {
    condition     = length(var.cluster_security_group_ids) > 0
    error_message = "At least one security group is required for the EKS control plane."
  }
}

variable "cluster_endpoint_private_access" {
  type        = bool
  description = "Whether the Kubernetes API should be reachable over private subnets"
  default     = true
}

variable "cluster_endpoint_public_access" {
  type        = bool
  description = "Whether to expose the Kubernetes API over the internet"
  default     = false
}

variable "cluster_enabled_log_types" {
  type        = list(string)
  description = "Optional EKS control plane log types (api, audit, authenticator, controllerManager, scheduler)"
  default     = []
}

// ----------------------------- 节点组参数 -----------------------------
variable "node_group_name" {
  type        = string
  description = "Friendly name for the managed node group"
}

variable "node_role_arn" {
  type        = string
  description = "IAM role ARN attached to the EKS worker nodes"
}

variable "node_group_subnet_ids" {
  type        = list(string)
  description = "Subnets where worker nodes should be created"

  validation {
    condition     = length(var.node_group_subnet_ids) >= 1
    error_message = "Provide at least one subnet for the managed node group."
  }
}

variable "node_group_instance_types" {
  type        = list(string)
  description = "Allowed instance types for the managed node group"
  default     = ["t3.medium"]
}

variable "node_group_capacity_type" {
  type        = string
  description = "ON_DEMAND or SPOT"
  default     = "ON_DEMAND"
}

variable "node_group_disk_size" {
  type        = number
  description = "EBS volume size (GiB) attached to each node"
  default     = 50
}

variable "node_group_desired_size" {
  type        = number
  description = "Desired worker count"
  default     = 2
}

variable "node_group_min_size" {
  type        = number
  description = "Minimum worker count"
  default     = 1
}

variable "node_group_max_size" {
  type        = number
  description = "Maximum worker count"
  default     = 3
}

variable "node_group_max_unavailable" {
  type        = number
  description = "How many nodes can be unavailable during managed node group updates"
  default     = 1
}

variable "node_group_labels" {
  type        = map(string)
  description = "Kubernetes labels applied to the managed node group"
  default     = {}
}

variable "node_group_tags" {
  type        = map(string)
  description = "AWS tags specific to the node group"
  default     = {}
}
