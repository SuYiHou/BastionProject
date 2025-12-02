variable "environment" {
  type        = string
  description = "Environment label for tagging"
}

variable "name_prefix" {
  type        = string
  description = "Global prefix used when naming archive resources"
}

variable "cluster_name" {
  type        = string
  description = "Target EKS cluster name; used when naming log groups"
}

variable "log_retention_in_days" {
  type        = number
  description = "Retention setting (days) for EKS control plane logs"
  default     = 30
}

variable "application_log_retention_in_days" {
  type        = number
  description = "Retention setting (days) for application log group"
  default     = 30
}

variable "application_log_group_name" {
  type        = string
  description = "Optional override for the application log group's name"
  default     = null
}

variable "create_archive_bucket" {
  type        = bool
  description = "Whether to provision an S3 bucket for long-term log archiving"
  default     = true
}

variable "archive_bucket_name" {
  type        = string
  description = "Custom S3 bucket name (must be globally unique). Falls back to generated name when null"
  default     = null
}

variable "archive_transition_days" {
  type        = number
  description = "Days before archived logs transition to GLACIER"
  default     = 90
}

variable "archive_expiration_days" {
  type        = number
  description = "Days before archived logs are permanently deleted"
  default     = 365
}

variable "archive_force_destroy" {
  type        = bool
  description = "Set true to allow Terraform to delete non-empty log archive buckets"
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Extra tags merged onto every resource"
  default     = {}
}
