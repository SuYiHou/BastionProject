// Naming inputs keep every resource aligned with the wider platform conventions.
variable "name_prefix" {
  type        = string
  description = "Prefix used when naming bastion resources"
}

variable "environment" {
  type        = string
  description = "Environment identifier (dev/prod/etc.)"
}

// Network placement and connectivity configuration.
variable "vpc_id" {
  type        = string
  description = "VPC ID where the bastion host will be deployed"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "List of public subnets; the first one hosts the bastion"

  validation {
    condition     = length(var.public_subnet_ids) > 0
    error_message = "At least one public subnet ID is required for the bastion host."
  }
}

variable "ssh_allowed_cidr" {
  type        = list(string)
  description = "CIDR blocks allowed to initiate SSH to the bastion"
  default     = []
}

// Instance sizing, access, and AMI selection.
variable "instance_type" {
  type        = string
  description = "EC2 instance type for the bastion"
}

variable "key_name" {
  type        = string
  description = "Existing EC2 Key Pair name for SSH access"
}

variable "ami_id" {
  type        = string
  description = "AMI ID to use for the bastion instance"
}

variable "enable_ssm" {
  type        = bool
  description = "If true, attach the AmazonSSMManagedInstanceCore policy"
}

variable "root_volume_size" {
  type        = number
  description = "Size (GiB) of the root EBS volume"
}

// Optional custom tags merged on top of the defaults.
variable "tags" {
  type        = map(string)
  description = "Optional extra tags to merge onto each resource"
  default     = {}
}

variable "bastion_sg_id" {
  type        = string
  description = "Security group ID to attach to the bastion instance"
}

// 以下两个变量用于“复用 IAM 模块的产物”：
// - 外部 want 复用角色/profile 时赋值；
// - 若保持默认 null，则当前模块会自建 role/profile。
variable "iam_role_name" {
  type        = string
  description = "Existing IAM role name to reuse for the bastion host"
  default     = null
}

variable "iam_instance_profile_name" {
  type        = string
  description = "Existing IAM instance profile name that surfaces the provided role"
  default     = null
}
