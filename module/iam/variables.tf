variable "name" {
  type        = string
  description = "Unique IAM role name"
}

variable "description" {
  type        = string
  description = "Friendly description shown in the IAM console"
  default     = ""
}

variable "environment" {
  type        = string
  description = "Environment label used for tagging"
}

variable "component" {
  type        = string
  description = "Component tag value to help classify the role"
  default     = "iam"
}

variable "tags" {
  type        = map(string)
  description = "Optional additional tags merged with the defaults"
  default     = {}
}

variable "assume_role_services" {
  type        = list(string)
  description = "Service principals allowed to assume the role"
  default     = []
}

variable "assume_role_arns" {
  type        = list(string)
  description = "Specific AWS principal ARNs allowed to assume the role"
  default     = []
}

variable "managed_policy_arns" {
  type        = list(string)
  description = "Managed policy ARNs to attach to the role"
  default     = []
}

variable "inline_policies" {
  type        = map(string)
  description = "Map of inline policy JSON documents keyed by policy name"
  default     = {}
}

variable "force_detach_policies" {
  type        = bool
  description = "Whether to forcibly detach policies before destroying the role"
  default     = true
}

variable "create_instance_profile" {
  type        = bool
  description = "If true, create an instance profile tied to the role"
  default     = false
}

variable "instance_profile_name" {
  type        = string
  description = "Optional custom instance profile name"
  default     = null
}

variable "inline_policy_statements" {
  type = map(list(object({
    sid       = optional(string)
    effect    = optional(string, "Allow")
    actions   = list(string)
    resources = list(string)
    condition = optional(map(map(string)))
  })))
  default = {}
}