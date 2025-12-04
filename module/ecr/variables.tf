variable "environment" {
  type        = string
  description = "Environment label for tagging"
}

variable "repository_name" {
  type        = string
  description = "ECR repository name"
}

variable "image_tag_mutability" {
  type        = string
  description = "MUTABLE or IMMUTABLE"
  default     = "MUTABLE"
}

variable "scan_on_push" {
  type        = bool
  description = "Enable ECR image scanning on push"
  default     = true
}

variable "encryption_type" {
  type        = string
  description = "AES256 or KMS"
  default     = "AES256"
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN when encryption_type is KMS"
  default     = null
}

variable "lifecycle_policy" {
  type        = string
  description = "JSON lifecycle policy document"
  default     = null
}

variable "repository_policy" {
  type        = string
  description = "Optional repository policy JSON"
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Extra tags merged onto repository"
  default     = {}
}
