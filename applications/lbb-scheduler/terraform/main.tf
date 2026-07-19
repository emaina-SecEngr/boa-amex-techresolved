# ============================================================
# LBBS Terraform — Main Configuration
# ============================================================
# This file defines the AWS provider and backend configuration.
#
# HOW TO USE:
#   cd terraform
#   terraform init      → Download AWS provider
#   terraform plan      → Preview changes
#   terraform apply     → Create resources
#   terraform destroy   → Delete everything
# ============================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # ── Remote State Storage (uncomment when S3 bucket exists) ──
  # backend "s3" {
  #   bucket         = "lbbs-terraform-state"
  #   key            = "production/terraform.tfstate"
  #   region         = "us-west-2"
  #   encrypt        = true
  #   dynamodb_table = "lbbs-terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "LBBS"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Course      = "SFWE-402"
      Owner       = "Eliud Maina"
    }
  }
}
