# ============================================================
# environments/management/main.tf
# Deploys into Management account (682391277575)
# AWS CLI profile: default
#
# WHAT LIVES HERE:
# Phase 1 only — Organization governance, Identity Center, SCPs
# NO workloads, NO security tooling, NO application resources
# This account is governance-only by architectural principle
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
    bucket         = "abuhari-terraform-state-682391277575"
    key            = "boa-amex/management/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "abuhari-terraform-state-lock"
    profile        = "default"
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "default"

  default_tags {
    tags = {
      Project         = "BOA-AMEX-TechResolved"
      Owner           = "Eliud-Maina"
      Consultant      = "Abuhari-Consulting-Services"
      Environment     = "Management"
      ManagedBy       = "Terraform"
      ComplianceScope = "PCI-DSS-v4 OCC-12CFR30 NIST-800-53"
      Phase           = "1-Foundation"
      Repository      = "boa-amex-techresolved"
    }
  }
}

# ============================================================
# MODULE CALL — aws-organization
# Phase 1, Module 1 — must be complete before all others
#
# IMPORT REQUIRED before first apply:
#   terraform import module.aws_organization.aws_organizations_organization.main r-iaiz
#   terraform import module.aws_organization.aws_organizations_account.security_tooling 368351959735
# ============================================================
module "aws_organization" {
  source = "../../modules/aws-organization"

  aws_region            = var.aws_region
  project_prefix        = var.project_prefix
  organization_id       = var.organization_id
  management_account_id = var.management_account_id
  security_tooling_account_id = var.security_tooling_account_id

  # OU structure — create all OUs
  create_security_ou       = true
  create_production_ou     = true
  create_non_production_ou = true
  create_pipeline_ou       = true
  create_compliance_ou     = true

  # Account creation — all false until deliberately enabled
  # Enable audit account FIRST before any workload accounts
  create_audit_account        = true
  create_pci_cde_account      = false
  create_core_banking_account = false
  create_dev_account          = false
  create_pipeline_account     = false

  # Delegated administrator — enable after Phase 2 is deployed
  # Security Tooling must have GuardDuty/SecHub running first
  enable_guardduty_delegated_admin   = false
  enable_securityhub_delegated_admin = false
  enable_detective_delegated_admin   = false
  enable_config_delegated_admin      = false

  common_tags = var.common_tags
}

# ============================================================
# OUTPUTS
# ============================================================
output "organization_id" {
  value = module.aws_organization.organization_id
}

output "root_id" {
  value = module.aws_organization.root_id
}

output "ou_structure" {
  value = {
    security       = module.aws_organization.security_ou_id
    production     = module.aws_organization.production_ou_id
    non_production = module.aws_organization.non_production_ou_id
    pipeline       = module.aws_organization.pipeline_ou_id
    compliance     = module.aws_organization.compliance_ou_id
  }
}

output "delegated_admin_status" {
  value = module.aws_organization.delegated_admin_status
}

output "verify_commands" {
  value = {
    organization = module.aws_organization.verify_organization_command
    ous          = module.aws_organization.verify_ous_command
    accounts     = module.aws_organization.verify_accounts_command
    import       = module.aws_organization.import_commands
  }
}