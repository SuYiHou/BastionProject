environment      = "dev"
name_prefix      = "mycorp-dev"
vpc_id           = "vpc-xxxxxxxx"
public_subnet_id = "subnet-xxxxxxxx"
ssh_allowed_cidr = [
  "153.242.124.14/32"
]
instance_type    = "t3.medium"
key_name         = "game-slot-dev-keypair"
ami_id           = "ami-007e5a061b93ceb2f"