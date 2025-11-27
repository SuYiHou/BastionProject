variable "region" {
  type        = string
  description = "AWS region"
  default     = "ap-northeast-1"
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

variable "vpc_id" {
  type        = string
  description = "Existing VPC ID where bastion will be placed"
}

variable "public_subnet_id" {
  type        = string
  description = "Public subnet ID for bastion instance"
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