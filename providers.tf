terraform {
  required_providers {
    aws = {
      source  = "hashicorp/terraform-provider-aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket            = "game-slot-terraform-state"
    key               = "bastion/terraform.tfstate"
    region            = "ap-southeast-2"
    dynamodb_endpoint = "terraform-locks"
    encrypt           = true
  }
}

provider "aws" {
  region = "ap-southeast-2"

  default_tags {
    tags = {
      Project     = "platform"
      Component   = "bastion"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

