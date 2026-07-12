# ============================================================
# environments/security-tooling/main.tf
# Deploys into Security Tooling account (368351959735)
# AWS CLI profile: security-tooling
#
# WHAT LIVES HERE:
# All security infrastructure — GuardDuty, Security Hub,
# Detective, Security Lake, Wiz, CrowdStrike, Log Archive
# This account is the nerve center of the security platform
# ============================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "abuhari-terraform-state-368351959735"
    key            = "boa-amex/security-tooling/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "abuhari-terraform-state-lock"
    profile        = "security-tooling"
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "security-tooling"

  default_tags {
    tags = {
      Project         = "BOA-AMEX-TechResolved"
      Owner           = "Eliud-Maina"
      Consultant      = "Abuhari-Consulting-Services"
      Environment     = "SecurityTooling"
      ManagedBy       = "Terraform"
      ComplianceScope = "PCI-DSS-v4 OCC-12CFR30 NIST-800-53"
      Phase           = "2-SecurityTooling"
      Repository      = "boa-amex-techresolved"
    }
  }
}

# ============================================================
# MODULE CALL — log-archive
# Phase 2, Module 1 — must be complete before all others
# Everything needs somewhere to send logs
# ============================================================
module "log_archive" {
  source = "../../modules/log-archive"

  aws_region                  = var.aws_region
  project_prefix              = var.project_prefix
  security_tooling_account_id = var.security_tooling_account_id
  management_account_id       = var.management_account_id
  organization_id             = var.organization_id

  # Bucket configuration
  log_archive_bucket_name    = "boa-amex-log-archive-368351959735"
  enable_object_lock         = true
  object_lock_retention_days = 2555
  enable_versioning          = true

  # Lifecycle policy
  standard_retention_days             = 90
  glacier_instant_retention_days      = 365
  glacier_deep_archive_retention_days = 2555

  # KMS
  kms_key_deletion_window_days = 30
  kms_key_rotation_enabled     = true

  # Log sources
  enable_cloudtrail_delivery    = true
  enable_guardduty_delivery     = true
  enable_config_delivery        = true
  enable_vpc_flow_logs_delivery = true
  enable_security_hub_delivery  = true

  # Sentinel — disabled until Azure subscription fixed
  # When ready: set to true and provide workspace details
  enable_sentinel_integration       = false
  sentinel_workspace_id             = ""
  sentinel_workspace_key            = ""
  sentinel_data_collection_endpoint = ""

  security_alert_email = var.security_alert_email
  common_tags          = var.common_tags
}
