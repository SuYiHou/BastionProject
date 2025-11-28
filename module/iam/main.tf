locals {
  // Shared tag set keeps everything traceable to env/component without duplicating definitions.
  base_tags = merge({
    Environment = var.environment,
    Component   = var.component,
    ManagedBy   = "terraform"
  }, var.tags)
}

// Construct the assume role policy to allow both AWS service principals and specific ARNs.
data "aws_iam_policy_document" "assume_role" {
  dynamic "statement" {
    for_each = length(var.assume_role_services) > 0 ? [var.assume_role_services] : []

    content {
      actions = ["sts:AssumeRole"]

      principals {
        type        = "Service"
        identifiers = statement.value
      }
    }
  }

  dynamic "statement" {
    for_each = length(var.assume_role_arns) > 0 ? [var.assume_role_arns] : []

    content {
      actions = ["sts:AssumeRole"]

      principals {
        type        = "AWS"
        identifiers = statement.value
      }
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.name
  description        = var.description
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  force_detach_policies = var.force_detach_policies

  tags = local.base_tags
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each   = toset(var.managed_policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "inline" {
  for_each = var.inline_policies
  name     = each.key
  role     = aws_iam_role.this.id
  policy   = each.value
}

resource "aws_iam_instance_profile" "this" {
  count = var.create_instance_profile ? 1 : 0

  name = coalesce(var.instance_profile_name, "${var.name}-profile")
  role = aws_iam_role.this.name
  tags = local.base_tags
}
