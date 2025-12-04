// ----------------------------------------------------------------------------
// 1) 网络层：使用自定义 network 模块一次性创建 VPC、子网、路由等组件。
//    该模块输出 VPC ID/子网等信息供后续安全组、EKS、Bastion 模块复用。
// ----------------------------------------------------------------------------
module "network" {
  source = "./module/network"

  name         = "platform-${var.environment}"
  vpc_cidr     = var.vpc_cidr
  environment  = var.environment
  cluster_name = "${var.eks_cluster_name}-${var.environment}"
}

// ----------------------------------------------------------------------------
// 2) 安全组层：根据统一定义生成多组 SG；
//    - bastion: 允许受控 IP SSH；
//    - private_compute: 给 EKS/EC2 节点用；
//    - eks_alb: 供对外 LB 使用。
// ----------------------------------------------------------------------------
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

// ----------------------------------------------------------------------------
// 针对 monorepo 微服务：将所有服务及其 ECR/CI 参数汇总到 microservices 变量中，
// 这里先定义默认值并 merge 用户传入的配置，后面统一 for_each 创建一批 ECR/CICD 模块。
// ----------------------------------------------------------------------------
locals {
  microservice_defaults = {
    ecr_repository_name      = null
    ecr_image_tag_mutability = "MUTABLE"
    ecr_scan_on_push         = true
    ecr_encryption_type      = "AES256"
    ecr_kms_key_arn          = null
    ecr_lifecycle_policy     = null
    ecr_repository_policy    = null

    codebuild_source_type             = null
    codebuild_source_location         = null
    codebuild_buildspec               = "buildspec.yml"
    codebuild_image                   = "aws/codebuild/standard:6.0"
    codebuild_compute_type            = "BUILD_GENERAL1_SMALL"
    codebuild_privileged_mode         = false
    codebuild_environment_variables   = {}
    codebuild_artifact_path           = "build"
    codebuild_log_retention_days      = 30
    codebuild_timeout_minutes         = 30
    codebuild_git_clone_depth         = 1
    codebuild_ecr_access              = true
    codebuild_extra_policy_statements = []

    cicd_create_artifact_bucket        = true
    cicd_artifact_bucket_name          = null
    cicd_artifact_bucket_force_destroy = false
    cicd_existing_artifact_bucket_arn  = null

    codedeploy_deployment_config        = "CodeDeployDefault.AllAtOnce"
    codedeploy_auto_scaling_group_names = []
    codedeploy_target_tag_key           = null
    codedeploy_target_tag_value         = null
  }

  microservices = { for svc_name, svc_cfg in var.microservices :
    svc_name => merge(local.microservice_defaults, svc_cfg)
  }
}

// ----------------------------------------------------------------------------
// 3) IAM：先为 Bastion 创建专属角色/实例配置文件，后续传递给 Bastion 模块复用。
// ----------------------------------------------------------------------------
module "iam_bastion" {
  source = "./module/iam"

  // 专门为 bastion 输出一套角色 + 实例 profile：
  // 1. `create_instance_profile` 由变量控制，可灵活关闭。
  // 2. name/assume_role_services 使用统一命名（含环境前缀）并仅允许 EC2 假设该角色。
  // 3. `managed_policy_arns` 根据 enable_ssm 动态附加 SSM 基础策略，保持旧逻辑一致。
  force_detach_policies   = var.force_detach_policies
  create_instance_profile = var.create_instance_profile
  instance_profile_name   = var.instance_profile_name
  environment             = var.environment
  name                    = "${var.name_prefix}-${var.environment}-bastion-role"
  assume_role_services    = ["ec2.amazonaws.com"]
  managed_policy_arns     = var.enable_ssm ? ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"] : []
}

// ----------------------------------------------------------------------------
// 4) Bastion：在公有子网中部署单台跳板机，复用上一步产出的 IAM 角色。
// ----------------------------------------------------------------------------
module "bastion" {
  source = "./module/bastion"

  // 传入 iam 模块产出的角色与实例 profile，保证 bastion 只消费既有 IAM 资源，而不在本模块重复创建。
  // 这样权限、策略、生命周期都集中在 iam 模块维护，后续审计或扩展时只需要修改一处。
  bastion_sg_id             = module.security_groups.security_group_ids["bastion"]
  iam_role_name             = module.iam_bastion.role_name
  iam_instance_profile_name = module.iam_bastion.instance_profile_name
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

// ----------------------------------------------------------------------------
// 5) IAM：为 EKS 控制面创建角色（允许 EKS 服务扮演、附加官方托管策略）。
// ----------------------------------------------------------------------------
module "iam_eks_cluster_role" {
  source = "./module/iam"

  environment          = var.environment
  name                 = "${var.name_prefix}-${var.environment}-eks-cluster-role"
  description          = "IAM role assumed by the EKS control plane"
  assume_role_services = ["eks.amazonaws.com"]
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_VPC_ResourceController"
  ]
  force_detach_policies   = true
  create_instance_profile = false
}

// ----------------------------------------------------------------------------
// 6) IAM：为 EKS 托管节点组创建 EC2 角色（拥有调用 EKS/ECR/CNI 必要权限）。
// ----------------------------------------------------------------------------
module "iam_eks_node_role" {
  source = "./module/iam"

  environment          = var.environment
  name                 = "${var.name_prefix}-${var.environment}-eks-node-role"
  description          = "IAM role used by EKS managed node groups"
  assume_role_services = ["ec2.amazonaws.com"]
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ]
  force_detach_policies   = true
  create_instance_profile = false
}

// ----------------------------------------------------------------------------
// 7) Observability：集中管理 CloudWatch Log Group + 日志归档桶，方便后续扩展到 ELK/Firehose。
// ----------------------------------------------------------------------------
module "observability" {
  source = "./module/observability"

  environment                       = var.environment
  name_prefix                       = var.name_prefix
  cluster_name                      = "${var.eks_cluster_name}-${var.environment}"
  log_retention_in_days             = var.observability_log_retention_days
  application_log_retention_in_days = var.observability_app_log_retention_days
  create_archive_bucket             = var.observability_create_archive_bucket
  archive_bucket_name               = var.observability_archive_bucket_name
  archive_transition_days           = var.observability_archive_transition_days
  archive_expiration_days           = var.observability_archive_expiration_days
  archive_force_destroy             = var.observability_archive_force_destroy
}

// ----------------------------------------------------------------------------
// 8) EKS：使用自定义模块创建控制面 + 默认托管节点组，完全复用前面输出的 VPC、SG、IAM。
// ----------------------------------------------------------------------------
module "eks" {
  source = "./module/eks"

  environment                     = var.environment
  cluster_name                    = "${var.eks_cluster_name}-${var.environment}"
  cluster_version                 = var.eks_cluster_version
  cluster_role_arn                = module.iam_eks_cluster_role.role_arn
  cluster_subnet_ids              = concat(module.network.private_subnet_ids, module.network.public_subnet_ids)
  cluster_security_group_ids      = [module.security_groups.security_group_ids["private_compute"]]
  cluster_endpoint_private_access = var.eks_cluster_endpoint_private_access
  cluster_endpoint_public_access  = var.eks_cluster_endpoint_public_access
  cluster_enabled_log_types       = var.eks_cluster_enabled_log_types

  node_group_name            = "${var.eks_cluster_name}-${var.environment}-default-ng"
  node_role_arn              = module.iam_eks_node_role.role_arn
  node_group_subnet_ids      = module.network.private_subnet_ids
  node_group_instance_types  = var.eks_node_instance_types
  node_group_capacity_type   = var.eks_node_capacity_type
  node_group_disk_size       = var.eks_node_disk_size
  node_group_desired_size    = var.eks_node_desired_size
  node_group_min_size        = var.eks_node_min_size
  node_group_max_size        = var.eks_node_max_size
  node_group_max_unavailable = var.eks_node_max_unavailable
  node_group_labels          = var.eks_node_labels
  node_group_tags            = var.eks_node_tags

  // 需在 EKS 启用日志前确保 CloudWatch Log Group 已创建，避免默认 7 天保留期。
  depends_on = [module.observability]
}

// ----------------------------------------------------------------------------
// 9) 每个微服务 1 个 ECR 仓库：命名规则为 <prefix>-<env>-<service>，方便按服务独立发布。
// ----------------------------------------------------------------------------
module "ecr_microservices" {
  for_each = local.microservices
  source   = "./module/ecr"

  environment          = var.environment
  repository_name      = coalesce(each.value.ecr_repository_name, "${var.name_prefix}-${var.environment}-${each.key}")
  image_tag_mutability = each.value.ecr_image_tag_mutability
  scan_on_push         = each.value.ecr_scan_on_push
  encryption_type      = each.value.ecr_encryption_type
  kms_key_arn          = each.value.ecr_kms_key_arn
  lifecycle_policy     = each.value.ecr_lifecycle_policy
  repository_policy    = each.value.ecr_repository_policy
}

// ----------------------------------------------------------------------------
// 10) 每个微服务一套 CodeBuild + CodeDeploy：GitLab 提交只需触发对应服务的 CI，即可构建/部署。
// ----------------------------------------------------------------------------
module "cicd_microservices" {
  for_each = local.microservices
  source   = "./module/cicd"

  environment = var.environment
  name_prefix = "${var.name_prefix}-${each.key}"

  create_artifact_bucket        = each.value.cicd_create_artifact_bucket
  artifact_bucket_name          = each.value.cicd_artifact_bucket_name
  artifact_bucket_force_destroy = each.value.cicd_artifact_bucket_force_destroy
  existing_artifact_bucket_arn  = each.value.cicd_existing_artifact_bucket_arn

  codebuild_source_type     = each.value.codebuild_source_type
  codebuild_source_location = each.value.codebuild_source_location
  codebuild_buildspec       = each.value.codebuild_buildspec
  codebuild_image           = each.value.codebuild_image
  codebuild_compute_type    = each.value.codebuild_compute_type
  codebuild_privileged_mode = each.value.codebuild_privileged_mode
  codebuild_environment_variables = merge(each.value.codebuild_environment_variables, {
    IMAGE_REPO = module.ecr_microservices[each.key].repository_url
  })
  codebuild_artifact_path           = each.value.codebuild_artifact_path
  codebuild_log_retention_in_days   = each.value.codebuild_log_retention_days
  codebuild_timeout_minutes         = each.value.codebuild_timeout_minutes
  codebuild_git_clone_depth         = each.value.codebuild_git_clone_depth
  codebuild_ecr_access              = each.value.codebuild_ecr_access
  codebuild_extra_policy_statements = each.value.codebuild_extra_policy_statements

  codedeploy_deployment_config        = each.value.codedeploy_deployment_config
  codedeploy_auto_scaling_group_names = each.value.codedeploy_auto_scaling_group_names
  codedeploy_target_tag_key           = each.value.codedeploy_target_tag_key
  codedeploy_target_tag_value         = each.value.codedeploy_target_tag_value
}

// ----------------------------------------------------------------------------
// 9) ECR：集中创建镜像仓库，方便 CodeBuild 推送/应用拉取。
// ----------------------------------------------------------------------------
