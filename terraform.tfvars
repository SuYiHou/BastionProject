environment      = "dev"
name_prefix      = "mycorp"
vpc_cidr         = "10.0.0.0/16"
eks_cluster_name = "game-test"
ssh_allowed_cidr = [
  "153.242.124.14/32"
]
instance_type         = "t3.medium"
key_name              = "game-slot-dev-keypair"
ami_id                = "ami-007e5a061b93ceb2f"
terraform_dev_profile = "Terraform-dev"
region                = "ap-southeast-2"