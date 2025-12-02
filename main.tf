module "network" {
  source = "./module/network"

  name         = "platform-${var.environment}"
  vpc_cidr     = var.vpc_cidr
  environment  = var.environment
  cluster_name = "${var.eks_cluster_name}-${var.environment}"
}

module "security_groups" {
  source      = "./module/security_group"
  name_prefix = "${var.name_prefix}-${var.environment}"
  name        = "${var.name_prefix}-${var.environment}"
  environment = var.environment
  vpc_id      = module.network.vpc_id
  tags        = {} // 需要可额外 merge
  vpc_cidr    = var.vpc_cidr
  security_groups = {
    bastion = {
      description = "Bastion host ingress policy"
      ingress = [
        {
          description = "SSH from admin IPs"
          protocol    = "tcp"
          from_port   = 22
          to_port     = 22
          cidr_blocks = var.ssh_allowed_cidr
        }
      ]
      egress = [
        {
          description = "Allow outbound to private ranges"
          protocol    = "-1"
          from_port   = 0
          to_port     = 0
          cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
        }
      ]
    }

    private_compute = {
      description = "Private workloads (EKS/EC2) baseline"
      ingress = [
        {
          description = "SSH from bastion"
          protocol    = "tcp"
          from_port   = 22
          to_port     = 22
          sg_sources  = ["bastion"]
        },
        {
          description = "Intra-node communication"
          protocol    = "-1"
          from_port   = 0
          to_port     = 0
          sg_sources  = ["private_compute"]
        }
      ]
      egress = [
        {
          description = "Full egress via NAT"
          protocol    = "-1"
          from_port   = 0
          to_port     = 0
          cidr_blocks = ["0.0.0.0/0"]
        }
      ]
    }

    eks_alb = {
      description = "Internet-facing ALB"
      ingress = [
        {
          description = "HTTP"
          protocol    = "tcp"
          from_port   = 80
          to_port     = 80
          cidr_blocks = ["0.0.0.0/0"]
        },
        {
          description = "HTTPS"
          protocol    = "tcp"
          from_port   = 443
          to_port     = 443
          cidr_blocks = ["0.0.0.0/0"]
        }
      ]
      egress = [
        {
          description = "Forward traffic to nodes"
          protocol    = "-1"
          from_port   = 0
          to_port     = 0
          sg_sources  = ["private_compute"]
        }
      ]
    }
  }
}

module "bastion" {
  source = "./module/bastion"

  // 传入 iam 模块产出的角色与实例 profile，保证 bastion 只消费既有 IAM 资源，而不在本模块重复创建。
  // 这样权限、策略、生命周期都集中在 iam 模块维护，后续审计或扩展时只需要修改一处。
  bastion_sg_id             = module.security_groups.security_group_ids["bastion"]
  iam_role_name             = module.iam.role_name
  iam_instance_profile_name = module.iam.instance_profile_name
  name_prefix               = var.name_prefix
  environment               = var.environment
  vpc_id                    = module.network.vpc_id
  public_subnet_ids         = module.network.public_subnet_ids
  ssh_allowed_cidr          = var.ssh_allowed_cidr
  instance_type             = var.instance_type
  key_name                  = var.key_name
  ami_id                    = var.ami_id
  enable_ssm                = var.enable_ssm
  root_volume_size          = var.root_volume_size
}

module "iam" {
  source = "./module/iam"

  // 专门为 bastion 输出一套角色 + 实例 profile：
  // 1. `create_instance_profile = true`：确保可以把角色挂到 EC2。
  // 2. name/assume_role_services 使用统一命名（含环境前缀）并仅允许 EC2 假设该角色。
  // 3. `managed_policy_arns` 根据 enable_ssm 动态附加 SSM 基础策略，保持旧逻辑一致。
  force_detach_policies   = true
  create_instance_profile = true
  instance_profile_name   = null
  environment             = var.environment
  name                    = "${var.name_prefix}-${var.environment}-bastion-role"
  assume_role_services    = ["ec2.amazonaws.com"]
  managed_policy_arns     = var.enable_ssm ? ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"] : []
}
