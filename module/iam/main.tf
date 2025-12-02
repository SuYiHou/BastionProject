// 通用 IAM 角色模块：
// - 通过变量注入受信任主体 (service / aws account)；
// - 支持同时附加托管策略与内联策略；
// - 可选创建 Instance Profile 供 EC2/Lambda 等服务挂载。
locals {
  // Shared tag set keeps everything traceable to env/component without duplicating definitions.
  base_tags = merge({
    Environment = var.environment,
    Component   = var.component,
    ManagedBy   = "terraform"
  }, var.tags)
}

locals {
  rendered_inline_policies = {
    for policy_name, statements in var.inline_policy_statements :
    policy_name => jsonencode({
      Version   = "2012-10-17"
      Statement = [
        for stmt in statements : merge(
          {
            Sid      = try(stmt.sid, null)
            Effect   = try(stmt.effect, "Allow")
            Action   = stmt.actions
            Resource = stmt.resources
          },
            stmt.condition == null ? {} : { Condition = stmt.condition }
        )
      ]
    })
  }
}

// Construct the assume role policy to allow both AWS service principals and specific ARNs.
data "aws_iam_policy_document" "assume_role" {
  // 当调用方传入 service principal 列表时，循环生成 allow sts:AssumeRole 语句。
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

  // 同理，如果传入指定 AWS 账号/角色 ARN，也以同样方式写入信任策略，
  // 便于跨账号/特定用户承担该角色。
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

// 真正创建 IAM Role，并套用上面生成的信任策略。
resource "aws_iam_role" "this" {
  name                 = var.name
  description          = var.description
  assume_role_policy   = data.aws_iam_policy_document.assume_role.json
  force_detach_policies = var.force_detach_policies

  tags = local.base_tags
}

// 根据传入的 managed policy 列表循环附加 AWS 托管策略（或自定义的 ARN）。
resource "aws_iam_role_policy_attachment" "managed" {
  for_each   = toset(var.managed_policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}

// 支持传入 map(name => json) 的方式创建内联策略，方便补充额外权限。
resource "aws_iam_role_policy" "inline" {
  for_each = var.inline_policies
  name     = each.key
  role     = aws_iam_role.this.id
  policy = local.rendered_inline_policies[each.key]
}

// 如需 EC2/SSM 等服务使用该角色，则自动创建 Instance Profile（一个角色最多只能绑一个 profile）。
resource "aws_iam_instance_profile" "this" {
  count = var.create_instance_profile ? 1 : 0

  name = coalesce(var.instance_profile_name, "${var.name}-profile")
  role = aws_iam_role.this.name
  tags = local.base_tags
}
