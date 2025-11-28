variable "name_prefix" {
  type        = string
  description = "Prefix used when naming bastion resources"
}

variable "environment" {
  type        = string
  description = "Environment identifier (dev/prod/etc.)"
}

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

variable "instance_type" {
  type        = string
  description = "EC2 instance type for the bastion"
  default     = "t3.micro"
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
  default     = true
}

variable "root_volume_size" {
  type        = number
  description = "Size (GiB) of the root EBS volume"
  default     = 20
}

variable "tags" {
  type        = map(string)
  description = "Optional extra tags to merge onto each resource"
  default     = {}
}
