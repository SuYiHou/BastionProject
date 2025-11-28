// Build a shared tag map so every resource created by this module is labeled identically.
locals {
  base_tags = merge({
    Environment = var.environment,
    Component   = "bastion",
    ManagedBy   = "terraform"
  }, var.tags)
}

// IAM policy document that allows EC2 instances to assume the generated role.
data "aws_iam_policy_document" "instance_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

// IAM role assumed by the bastion instance for optional SSM and future permissions.
resource "aws_iam_role" "this" {
  name               = "${var.name_prefix}-${var.environment}-bastion"
  assume_role_policy = data.aws_iam_policy_document.instance_assume_role.json

  tags = local.base_tags
}

// Instance profile that wires the IAM role onto the EC2 instance.
resource "aws_iam_instance_profile" "this" {
  name = "${var.name_prefix}-${var.environment}-bastion"
  role = aws_iam_role.this.name
}

// Optionally attach SSM core permissions so the host can be accessed via Session Manager.
resource "aws_iam_role_policy_attachment" "ssm" {
  count      = var.enable_ssm ? 1 : 0
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

// Single EC2 instance acting as the bastion host.
resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id = element(var.public_subnet_ids, 0)
  vpc_security_group_ids = [var.bastion_sg_id]
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.this.name
  associate_public_ip_address = true
  monitoring                  = true

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

