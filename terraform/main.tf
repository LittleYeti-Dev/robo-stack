terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }

  # Local backend for now. To use S3 backend for team collaboration:
  # Uncomment below and create the S3 bucket first
  # backend "s3" {
  #   bucket         = "robo-stack-terraform-state"
  #   key            = "dev/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region
}

locals {
  common_tags = {
    Project     = "robo-stack"
    Environment = var.environment
    ManagedBy   = "terraform"
    Sprint      = "1"
  }
}
