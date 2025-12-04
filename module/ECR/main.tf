// -----------------------------------------------------------------------------
// ECR 模块：创建一个自带扫描、加密、生命周期策略的镜像仓库。
// - 支持可选的 KMS 加密、tag 变更策略、生命周期清理；
// - 输出 repo 名称/ARN/URL，供 CodeBuild 等构建作业直接引用；
// - 可附加自定义 repository policy，让指定账户/角色拥有推拉权限。
// -----------------------------------------------------------------------------
locals {
  base_tags = merge({
    Environment = var.environment,
    Component   = "ecr",
    ManagedBy   = "terraform"
  }, var.tags)
}

resource "aws_ecr_repository" "this" {
  name                 = var.repository_name
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = var.encryption_type
    kms_key         = var.encryption_type == "KMS" ? var.kms_key_arn : null
  }

  tags = local.base_tags
}

resource "aws_ecr_lifecycle_policy" "this" {
  count      = var.lifecycle_policy == null ? 0 : 1
  repository = aws_ecr_repository.this.name
  policy     = var.lifecycle_policy
}

resource "aws_ecr_repository_policy" "this" {
  count      = var.repository_policy == null ? 0 : 1
  repository = aws_ecr_repository.this.name
  policy     = var.repository_policy
}
