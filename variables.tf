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
  type = string
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
  type        = string
  default     = "t3.micro"
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
  default     = true
}
