// Build a shared tag map so every resource created by this module is labeled identically.
locals {
  base_tags = merge({
    Environment = var.environment,
    Component   = "bastion",
    ManagedBy   = "terraform"
  }, var.tags)

  // 当上层传入 role name 时，意味着需要复用 iam 模块里的角色/实例配置文件。
  // 这里用布尔值提前计算，后面所有 IAM 资源的 count、引用都可以复用这个判断，避免重复写条件。
  use_external_iam_role = var.iam_role_name != null && trimspace(var.iam_role_name) != ""
}

// IAM policy document that allows EC2 instances to assume the generated role.
data "aws_iam_policy_document" "instance_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

// IAM role assumed by the bastion instance for optional SSM and future permissions.
// 
// 1. 当 need 自建角色时，保持旧逻辑创建 `${name_prefix}-${environment}-bastion`。
// 2. 如果 use_external_iam_role = true，则完全跳过，避免与 iam 模块里的角色重名/冲突。
resource "aws_iam_role" "this" {
  count              = local.use_external_iam_role ? 0 : 1
  name               = "${var.name_prefix}-${var.environment}-bastion"
  assume_role_policy = data.aws_iam_policy_document.instance_assume_role.json

  tags = local.base_tags
}

// Instance profile that wires the IAM role onto the EC2 instance.
// 
// 与上面的角色保持相同的开关：外部已创建实例 profile 时不重复创建，
// 反之则沿用旧命名，为后面 EC2 实例提供 `iam_instance_profile`。
resource "aws_iam_instance_profile" "this" {
  count = local.use_external_iam_role ? 0 : 1
  name  = "${var.name_prefix}-${var.environment}-bastion"
  role  = aws_iam_role.this[0].name
}

// Optionally attach SSM core permissions so the host can be accessed via Session Manager.
// 
// 这里仍然保持“模块自建角色才自动绑定 SSM”的原则：如果角色来自 iam 模块，权限由上层统一管控，避免产生 side effect。
resource "aws_iam_role_policy_attachment" "ssm" {
  count      = local.use_external_iam_role ? 0 : var.enable_ssm ? 1 : 0
  role       = aws_iam_role.this[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

// 统一“最终”要写入 EC2 的 role/profile 名称。
// - 外部复用：直接把传入的 `iam_role_name` / `iam_instance_profile_name` 透传下去。
// - 内部自建：通过 try() 读取刚刚创建的资源（count = 1 时对应 index 0）。
locals {
  bastion_iam_role_name         = local.use_external_iam_role ? var.iam_role_name : try(aws_iam_role.this[0].name, null)
  bastion_instance_profile_name = local.use_external_iam_role ? var.iam_instance_profile_name : try(aws_iam_instance_profile.this[0].name, null)
}

// Single EC2 instance acting as the bastion host.
resource "aws_instance" "this" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = element(var.public_subnet_ids, 0)
  vpc_security_group_ids = [var.bastion_sg_id]
  key_name               = var.key_name
  // 上面 local 已经规范化 profile 名称：要么复用 iam 模块的输出，要么使用当前模块创建的 profile。
  // 这里直接引用 local，后续无论扩展还是调试都只需要关注 local 的逻辑即可。
  iam_instance_profile        = local.bastion_instance_profile_name
  associate_public_ip_address = true
  monitoring                  = true

  lifecycle {
    precondition {
      // 防御性校验：如果调用者选择复用外部 role，也必须同时给出 profile 名称，否则 EC2 无法挂载角色。
      // 通过 lifecycle precondition 在 plan 阶段就失败，避免 apply 到一半才发现配置缺失。
      condition     = local.bastion_instance_profile_name != null
      error_message = "Either allow this module to create an instance profile or supply iam_instance_profile_name."
    }
  }

  // Enforce IMDSv2 so credentials cannot be fetched without session tokens.
  metadata_options {
    http_tokens = "required"
  }

  // Hardens the root volume with encryption and gives it predictable naming.
  root_block_device {
    encrypted   = true
    volume_size = var.root_volume_size
    volume_type = "gp3"
    tags = merge(local.base_tags, {
      Name = "${var.name_prefix}-${var.environment}-bastion-root"
    })
  }

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-${var.environment}-bastion"
  })
}
