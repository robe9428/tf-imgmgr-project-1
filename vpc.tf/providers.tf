# Backend setup
terraform {
  backend "s3" {
    key = "vpc.tfstate"
  }
}
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 2.0"
    }
  }
}
