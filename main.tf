module "bastion" {
  source = "./module/bastion"

  name_prefix       = var.name_prefix
  environment       = var.environment
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  ssh_allowed_cidr  = var.ssh_allowed_cidr
  instance_type     = var.instance_type
  key_name          = var.key_name
  ami_id            = var.ami_id
  enable_ssm        = var.enable_ssm
}

module "network" {
  source = "./module/network"

  name         = "platform-${var.environment}"
  vpc_cidr     = var.vpc_cidr
  environment  = var.environment
  cluster_name = "${var.eks_cluster_name}-${var.environment}"
}