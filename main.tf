module "bastion" {
  source = "./module"

  name_prefix = var.name_prefix
  environment = var.environment
  vpc_id = var.vpc_id
  ssh_allowed_cidr   = var.ssh_allowed_cidr
  instance_type      = var.instance_type
  key_name           = var.key_name
  ami_id             = var.ami_id
  enable_ssm         = var.enable_ssm
}