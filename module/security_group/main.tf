// module/security_groups/main.tf
locals {
  // 统一标签，便于计费/排错
  base_tags = merge({
    Environment = var.environment
    Component   = "security"
    ManagedBy   = "terraform"
  }, var.tags)
}

resource "aws_security_group" "this" {
    for_each = var.security_groups

  name = "${var.name_prefix}-${each.key}"
  description = each.value.description
  vpc_id = var.vpc_id

  tags = merge(local.base_tags, {
    name = "${var.name_prefix}-${each.key}"
  })
}

