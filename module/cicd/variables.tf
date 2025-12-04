variable "environment" {
  type        = string
  description = "Environment label for tagging"
}

variable "name_prefix" {
  type        = string
  description = "Global name prefix so CodeBuild/CodeDeploy follow existing naming conventions"
}

variable "tags" {
  type        = map(string)
  description = "Extra tags merged on top of the defaults"
  default     = {}
}

variable "create_artifact_bucket" {
  type        = bool
  description = "If true, create an S3 bucket to store build artifacts"
  default     = true
}

variable "artifact_bucket_name" {
  type        = string
  description = "Optional custom S3 bucket name for artifacts (must be globally unique)"
  default     = null
}

variable "artifact_bucket_force_destroy" {
  type        = bool
  description = "Allow Terraform to delete the artifact bucket even when it contains files"
  default     = false
}

variable "existing_artifact_bucket_arn" {
  type        = string
  description = "If you already have an artifact bucket, provide its ARN and set create_artifact_bucket=false"
  default     = null
}

variable "codebuild_source_type" {
  type        = string
  description = "Source provider type for CodeBuild (e.g., GITHUB, CODECOMMIT, S3)"
}

variable "codebuild_source_location" {
  type        = string
  description = "Location of the source repository or artifact"
}

variable "codebuild_buildspec" {
  type        = string
  description = "Path to the buildspec file"
  default     = "buildspec.yml"
}

variable "codebuild_image" {
  type        = string
  description = "Docker image used for the build environment"
  default     = "aws/codebuild/standard:6.0"
}

variable "codebuild_compute_type" {
  type        = string
  description = "Build compute size (BUILD_GENERAL1_SMALL/MEDIUM/LARGE)"
  default     = "BUILD_GENERAL1_SMALL"
}

variable "codebuild_privileged_mode" {
  type        = bool
  description = "Enable Docker-in-Docker; required for building container images"
  default     = false
}

variable "codebuild_environment_variables" {
  type        = map(string)
  description = "Environment variables injected into the build container"
  default     = {}
}

variable "codebuild_artifact_path" {
  type        = string
  description = "Prefix within the artifact bucket (e.g., releases/)"
  default     = "build"
}

variable "codebuild_log_retention_in_days" {
  type        = number
  description = "Retention (days) for the build log group"
  default     = 30
}

variable "codebuild_timeout_minutes" {
  type        = number
  description = "Build timeout in minutes"
  default     = 30
}

variable "codebuild_git_clone_depth" {
  type        = number
  description = "Shallow clone depth for Git repositories"
  default     = 1
}

variable "codebuild_ecr_access" {
  type        = bool
  description = "Grant the build role push/pull permissions to ECR"
  default     = false
}

variable "codebuild_extra_policy_statements" {
  type = list(object({
    sid       = optional(string)
    effect    = optional(string, "Allow")
    actions   = list(string)
    resources = list(string)
  }))
  description = "Additional IAM statements merged into the CodeBuild role policy"
  default     = []
}

variable "codedeploy_deployment_config" {
  type        = string
  description = "Deployment strategy (e.g., CodeDeployDefault.AllAtOnce, CodeDeployDefault.OneAtATime)"
  default     = "CodeDeployDefault.AllAtOnce"
}

variable "codedeploy_auto_scaling_group_names" {
  type        = list(string)
  description = "AutoScaling Groups that receive deployments"
  default     = []
}

variable "codedeploy_target_tag_key" {
  type        = string
  description = "Optional EC2 tag key for selecting deployment targets"
  default     = null
}

variable "codedeploy_target_tag_value" {
  type        = string
  description = "Optional EC2 tag value for selecting deployment targets"
  default     = null
}
