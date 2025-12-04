// -----------------------------------------------------------------------------
// CI/CD 模块：一站式创建 CodeBuild + CodeDeploy 资源
// - CodeBuild 负责从 Git 仓库取代码、编译/打包/推镜像；
// - CodeDeploy 则把构建产物部署到指定的 EC2/AutoScaling Group；
// - 该模块同时帮你准备 IAM 角色、日志组、S3 Artifact 桶，使用者只要填入仓库、分支、ASG 等信息即可。
// -----------------------------------------------------------------------------
locals {
  base_tags = merge({
    Environment = var.environment,
    Component   = "cicd",
    ManagedBy   = "terraform"
  }, var.tags)

  use_generated_bucket_name = var.artifact_bucket_name == null || trim(var.artifact_bucket_name) == ""

  generated_bucket_name = lower(replace("${var.name_prefix}-${var.environment}-artifact-${substr(md5(var.name_prefix), 0, 6)}", "_", "-"))

  codedeploy_target_defined = length(var.codedeploy_auto_scaling_group_names) > 0 || (var.codedeploy_target_tag_key != null && trim(var.codedeploy_target_tag_key) != "" && var.codedeploy_target_tag_value != null && trim(var.codedeploy_target_tag_value) != "")
}

// -----------------------------------------------------------------------------
// 1) S3 Artifact 桶：存放 CodeBuild 输出到 CodeDeploy/手工下载的产物。
// -----------------------------------------------------------------------------
resource "aws_s3_bucket" "artifacts" {
  count = var.create_artifact_bucket ? 1 : 0

  bucket        = local.use_generated_bucket_name ? local.generated_bucket_name : var.artifact_bucket_name
  force_destroy = var.artifact_bucket_force_destroy

  tags = merge(local.base_tags, {
    Purpose = "codebuild-artifacts"
  })
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  count = length(aws_s3_bucket.artifacts)

  bucket = aws_s3_bucket.artifacts[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "artifacts" {
  count = length(aws_s3_bucket.artifacts)

  bucket = aws_s3_bucket.artifacts[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  count = length(aws_s3_bucket.artifacts)

  bucket = aws_s3_bucket.artifacts[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

// -----------------------------------------------------------------------------
// 2) CodeBuild 日志组：集中所有构建输出，便于排查构建失败。
// -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "codebuild" {
  name              = "/codebuild/${var.name_prefix}-${var.environment}"
  retention_in_days = var.codebuild_log_retention_in_days

  tags = merge(local.base_tags, {
    Stream = "codebuild"
  })
}

// -----------------------------------------------------------------------------
// 3) IAM：为 CodeBuild 创建 service role，仅允许访问日志、S3 artifacts、ECR（可选）。
// -----------------------------------------------------------------------------
data "aws_iam_policy_document" "codebuild_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codebuild" {
  name               = "${var.name_prefix}-${var.environment}-codebuild"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume.json

  tags = local.base_tags
}

locals {
  codebuild_artifact_bucket_arn = try(aws_s3_bucket.artifacts[0].arn, var.existing_artifact_bucket_arn)
}

data "aws_iam_policy_document" "codebuild_inline" {
  statement {
    sid = "CloudWatchLogs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      aws_cloudwatch_log_group.codebuild.arn,
      "${aws_cloudwatch_log_group.codebuild.arn}:*"
    ]
  }

  statement {
    sid = "S3Artifacts"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:GetObjectVersion",
      "s3:ListBucket"
    ]
    resources = compact([
      local.codebuild_artifact_bucket_arn,
      local.codebuild_artifact_bucket_arn == null ? null : "${local.codebuild_artifact_bucket_arn}/*"
    ])
  }

  dynamic "statement" {
    for_each = var.codebuild_ecr_access ? [1] : []

    content {
      sid       = "ECRPullPush"
      actions   = ["ecr:GetAuthorizationToken", "ecr:BatchGetImage", "ecr:CompleteLayerUpload", "ecr:PutImage", "ecr:UploadLayerPart", "ecr:InitiateLayerUpload"]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = var.codebuild_extra_policy_statements

    content {
      sid       = lookup(statement.value, "sid", null)
      actions   = lookup(statement.value, "actions", [])
      resources = lookup(statement.value, "resources", ["*"])
      effect    = lookup(statement.value, "effect", "Allow")
    }
  }
}

resource "aws_iam_role_policy" "codebuild" {
  name   = "${var.name_prefix}-${var.environment}-codebuild"
  role   = aws_iam_role.codebuild.id
  policy = data.aws_iam_policy_document.codebuild_inline.json
}

// -----------------------------------------------------------------------------
// 4) CodeBuild 项目：指定源码位置、构建规格、环境变量等。
// -----------------------------------------------------------------------------
resource "aws_codebuild_project" "this" {
  name          = "${var.name_prefix}-${var.environment}-codebuild"
  description   = "Build project for ${var.name_prefix}"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = var.codebuild_timeout_minutes

  artifacts {
    type      = "S3"
    location  = local.codebuild_artifact_bucket_arn == null ? var.existing_artifact_bucket_arn : aws_s3_bucket.artifacts[0].bucket
    packaging = "ZIP"
    path      = var.codebuild_artifact_path
  }

  environment {
    compute_type                = var.codebuild_compute_type
    image                       = var.codebuild_image
    type                        = "LINUX_CONTAINER"
    privileged_mode             = var.codebuild_privileged_mode
    image_pull_credentials_type = "CODEBUILD"

    dynamic "environment_variable" {
      for_each = var.codebuild_environment_variables

      content {
        name  = environment_variable.key
        value = environment_variable.value
      }
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.codebuild.name
      stream_name = "build"
    }
  }

  source {
    type            = var.codebuild_source_type
    location        = var.codebuild_source_location
    git_clone_depth = var.codebuild_git_clone_depth
    buildspec       = var.codebuild_buildspec
  }

  tags = local.base_tags
}

// -----------------------------------------------------------------------------
// 5) CodeDeploy：Application + Deployment Group，用于推送到 ASG/Tagged EC2。
// -----------------------------------------------------------------------------
data "aws_iam_policy_document" "codedeploy_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codedeploy" {
  name               = "${var.name_prefix}-${var.environment}-codedeploy"
  assume_role_policy = data.aws_iam_policy_document.codedeploy_assume.json

  tags = local.base_tags
}

resource "aws_iam_role_policy_attachment" "codedeploy_managed" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

resource "aws_codedeploy_app" "this" {
  name             = "${var.name_prefix}-${var.environment}"
  compute_platform = "Server"

  tags = local.base_tags
}

resource "aws_codedeploy_deployment_group" "this" {
  app_name               = aws_codedeploy_app.this.name
  deployment_group_name  = "${var.name_prefix}-${var.environment}-dg"
  deployment_config_name = var.codedeploy_deployment_config
  service_role_arn       = aws_iam_role.codedeploy.arn
  autoscaling_groups     = var.codedeploy_auto_scaling_group_names

  dynamic "ec2_tag_filter" {
    for_each = var.codedeploy_target_tag_key != null && trim(var.codedeploy_target_tag_key) != "" ? [1] : []

    content {
      key   = var.codedeploy_target_tag_key
      type  = "KEY_AND_VALUE"
      value = var.codedeploy_target_tag_value
    }
  }

  trigger_configuration {
    trigger_events     = ["DeploymentStart", "DeploymentSuccess", "DeploymentFailure"]
    trigger_name       = "${var.name_prefix}-${var.environment}-codedeploy-trigger"
    trigger_target_arn = aws_cloudwatch_log_group.codebuild.arn
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  tags = local.base_tags

  lifecycle {
    precondition {
      condition     = local.codedeploy_target_defined
      error_message = "codedeploy_auto_scaling_group_names 或 codedeploy_target_tag_* 至少指定一种部署目标。"
    }
  }
}
