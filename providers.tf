terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # backend "s3" {
  #   bucket         = "game-slot-terraform-state"
  #   key            = "bastion/terraform.tfstate"
  #   region         = "ap-southeast-2"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.region
  profile = var.terraform_dev_profile

  default_tags {
    tags = {
      Project     = "platform"
      Component   = "bastion"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
