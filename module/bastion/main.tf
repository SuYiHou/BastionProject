locals {
  // Reuse consistent tagging so the bastion resources are easy to track
  base_tags = merge({
    Environment = var.environment,
    Component   = "bastion",
    ManagedBy   = "terraform"
  }, var.tags)
}

resource "aws_security_group" "this" {
  name        = "${var.name_prefix}-${var.environment}-bastion"
  description = "SSH access for bastion host"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow outbound access to the internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-${var.environment}-bastion"
  })
}

resource "aws_security_group_rule" "ssh_ingress" {
  for_each = toset(var.ssh_allowed_cidr)

  type              = "ingress"
  description       = "SSH access from allowed CIDR ${each.value}"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [each.value]
  security_group_id = aws_security_group.this.id
}

resource "aws_iam_role" "this" {
  name               = "${var.name_prefix}-${var.environment}-bastion"
  assume_role_policy = data.aws_iam_policy_document.instance_assume_role.json

  tags = local.base_tags
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name_prefix}-${var.environment}-bastion"
  role = aws_iam_role.this.name
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count      = var.enable_ssm ? 1 : 0
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "instance_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = element(var.public_subnet_ids, 0)
  vpc_security_group_ids      = [aws_security_group.this.id]
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.this.name
  associate_public_ip_address = true
  monitoring                  = true

  metadata_options {
    http_tokens = "required"
  }

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
