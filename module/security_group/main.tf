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

  name        = "${var.name_prefix}-${each.key}"
  description = each.value.description
  vpc_id      = var.vpc_id

  tags = merge(local.base_tags, {
    name = "${var.name_prefix}-${each.key}"
  })
}

/*
  以下 4 组 flatten + for_each 负责拆分每条 ingress/egress 规则，
  以便既能支持 CIDR，也能支持引用其他安全组。
*/

locals {
  ingress_cidr_rules = flatten(flatten([
    for sg_name, sg in var.security_groups : [
      for idx, rule in sg.ingress : [
        for cidr in lookup(rule, "cidr_blocks", []) : {
          id          = "${sg_name}-ingress-cidr-${idx}-${cidr}"
          sg_name     = sg_name
          description = rule.description
          protocol    = rule.protocol
          from_port   = rule.from_port
          to_port     = rule.to_port
          cidr_block  = cidr
        }
      ]
    ]
  ]))

  ingress_sg_rules = flatten(flatten([
    for sg_name, sg in var.security_groups : [
      for idx, rule in sg.ingress : [
        for src in lookup(rule, "sg_sources", []) : {
          id          = "${sg_name}-ingress-sg-${idx}-${src}"
          sg_name     = sg_name
          description = rule.description
          protocol    = rule.protocol
          from_port   = rule.from_port
          to_port     = rule.to_port
          source_sg   = src
        }
      ]
    ]
  ]))

  egress_cidr_rules = flatten(flatten([
    for sg_name, sg in var.security_groups : [
      for idx, rule in sg.egress : [
        for cidr in lookup(rule, "cidr_blocks", []) : {
          id          = "${sg_name}-egress-cidr-${idx}-${cidr}"
          sg_name     = sg_name
          description = rule.description
          protocol    = rule.protocol
          from_port   = rule.from_port
          to_port     = rule.to_port
          cidr_block  = cidr
        }
      ]
    ]
  ]))

  egress_sg_rules = flatten(flatten([
    for sg_name, sg in var.security_groups : [
      for idx, rule in sg.egress : [
        for dst in lookup(rule, "sg_sources", []) : {
          id          = "${sg_name}-egress-sg-${idx}-${dst}"
          sg_name     = sg_name
          description = rule.description
          protocol    = rule.protocol
          from_port   = rule.from_port
          to_port     = rule.to_port
          dest_sg     = dst
        }
      ]
    ]
  ]))
}

resource "aws_security_group_rule" "ingress_cidr" {
  for_each = {for rule in local.ingress_cidr_rules : rule.id => rule}

  type              = "ingress"
  description       = each.value.description
  protocol          = each.value.protocol
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  cidr_blocks       = [each.value.cidr_block]
  security_group_id = aws_security_group.this[each.value.sg_name].id
}

resource "aws_security_group_rule" "ingress_sg" {
  for_each = { for rule in local.ingress_sg_rules : rule.id => rule }

  type                     = "ingress"
  description              = each.value.description
  protocol                 = each.value.protocol
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  source_security_group_id = aws_security_group.this[each.value.source_sg].id
  security_group_id        = aws_security_group.this[each.value.sg_name].id
}

resource "aws_security_group_rule" "egress_cidr" {
  for_each = { for rule in local.egress_cidr_rules : rule.id => rule }

  type              = "egress"
  description       = each.value.description
  protocol          = each.value.protocol
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  cidr_blocks       = [each.value.cidr_block]
  security_group_id = aws_security_group.this[each.value.sg_name].id
}

resource "aws_security_group_rule" "egress_sg" {
  for_each = { for rule in local.egress_sg_rules : rule.id => rule }

  type                     = "egress"
  description              = each.value.description
  protocol                 = each.value.protocol
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  source_security_group_id = aws_security_group.this[each.value.dest_sg].id
  security_group_id        = aws_security_group.this[each.value.sg_name].id
}