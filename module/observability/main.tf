// -----------------------------------------------------------------------------
// Observability 模块：集中管理 EKS/Bastion 的基础日志与归档能力。
// - 预建 CloudWatch Log Group，控制 EKS 控制面与应用日志的保留天数；
// - 可选创建集中式 S3 日志桶（默认开启版本控制、生命周期、加密）；
// - 后续可以在 EKS 内部署 Fluent Bit / FireLens，将节点或应用日志打到 application log group。
// -----------------------------------------------------------------------------
locals {
  base_tags = merge({
    Environment = var.environment,
    Component   = "observability",
    ManagedBy   = "terraform"
  }, var.tags)

  default_bucket_name = lower(replace("${var.name_prefix}-${var.environment}-logs-${substr(md5(var.cluster_name), 0, 6)}", "_", "-"))
}

// 预创建控制面日志 log group，名称遵循 AWS 约定：/aws/eks/<cluster>/cluster。
resource "aws_cloudwatch_log_group" "eks_control_plane" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_in_days

  tags = merge(local.base_tags, {
    Stream = "eks-control-plane"
  })
}

// 额外 application log group，可供 Fluent Bit/FireLens/Firehose 写入。
resource "aws_cloudwatch_log_group" "eks_application" {
  name              = coalesce(var.application_log_group_name, "/aws/eks/${var.cluster_name}/application")
  retention_in_days = var.application_log_retention_in_days

  tags = merge(local.base_tags, {
    Stream = "eks-application"
  })
}

// 可选日志归档桶：用于保存超过 retention 的原始日志，或供 Firehose/Glue 导入。
resource "aws_s3_bucket" "archive" {
  count = var.create_archive_bucket ? 1 : 0

  bucket        = coalesce(var.archive_bucket_name, local.default_bucket_name)
  force_destroy = var.archive_force_destroy

  tags = merge(local.base_tags, {
    Purpose = "central-log-archive"
  })
}

resource "aws_s3_bucket_public_access_block" "archive" {
  count = length(aws_s3_bucket.archive)

  bucket = aws_s3_bucket.archive[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "archive" {
  count = length(aws_s3_bucket.archive)

  bucket = aws_s3_bucket.archive[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "archive" {
  count = length(aws_s3_bucket.archive)

  bucket = aws_s3_bucket.archive[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "archive" {
  count = length(aws_s3_bucket.archive)

  bucket = aws_s3_bucket.archive[0].id

  rule {
    id     = "archive-transition"
    status = "Enabled"

    transition {
      days          = var.archive_transition_days
      storage_class = "GLACIER"
    }

    expiration {
      days = var.archive_expiration_days
    }
  }
}
