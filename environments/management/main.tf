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
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
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

# Cross-account provider — Security Tooling account, where the
# Log Archive bucket lives. Assumes OrganizationAccountAccessRole
# via the local "security-tooling" AWS CLI profile.
provider "aws" {
  alias   = "security_tooling"
  region  = var.aws_region
  profile = "security-tooling"

  default_tags {
    tags = {
      Project     = "BOA-AMEX-TechResolved"
      Owner       = "Eliud-Maina"
      Consultant  = "Abuhari-Consulting-Services"
      Environment = "SecurityTooling"
      ManagedBy   = "Terraform"
      Phase       = "1-Foundation"
      Repository  = "boa-amex-techresolved"
    }
  }
}

provider "azuread" {
  tenant_id = "288a15d1-700c-482b-a591-7c1d4e6c4f3c"
  use_cli   = true
}

# ============================================================
# Log Archive bucket policy — grants the org CloudTrail trail
# permission to write to the existing bucket in Security Tooling.
# Trail ARN is constructed rather than referenced from the module
# output to avoid a dependency cycle (CloudTrail validates this
# policy at creation time, so the policy must exist first).
# ============================================================
locals {
  org_trail_arn = "arn:aws:cloudtrail:${var.aws_region}:${var.management_account_id}:trail/${var.project_prefix}-org-trail"
}

resource "aws_s3_bucket_policy" "cloudtrail_log_archive" {
  provider = aws.security_tooling
  bucket   = "abutech-amexsec-log-archive-368351959735"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = "arn:aws:s3:::abutech-amexsec-log-archive-368351959735"
        Condition = {
          StringEquals = {
            "aws:SourceArn" = local.org_trail_arn
          }
        }
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource = [
          "arn:aws:s3:::abutech-amexsec-log-archive-368351959735/org-cloudtrail/AWSLogs/${var.management_account_id}/*",
          "arn:aws:s3:::abutech-amexsec-log-archive-368351959735/org-cloudtrail/AWSLogs/${var.organization_id}/*"
        ]
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"  = "bucket-owner-full-control"
            "aws:SourceArn" = local.org_trail_arn
          }
        }
      }
    ]
  })
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

  aws_region                  = var.aws_region
  project_prefix              = var.project_prefix
  organization_id             = var.organization_id
  management_account_id       = var.management_account_id
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
  enable_guardduty_delegated_admin   = true
  enable_securityhub_delegated_admin = false
  enable_detective_delegated_admin   = false
  enable_config_delegated_admin      = false

  common_tags = var.common_tags
}
# ============================================================
# MODULE CALL — management-baseline
# Phase 1, Module 2 — org-wide CloudTrail + Config aggregator
# + root account protection + IAM password policy
#
# PREREQUISITE: aws-organization module complete ✅
# DELIVERS TO: Log Archive bucket in Security Tooling account
# ============================================================
module "management_baseline" {
  source = "../../modules/management-baseline"

  aws_region                  = var.aws_region
  project_prefix              = var.project_prefix
  management_account_id       = var.management_account_id
  security_tooling_account_id = var.security_tooling_account_id
  organization_id             = var.organization_id

  # Org-wide CloudTrail — delivers to existing Log Archive bucket
  enable_org_cloudtrail            = true
  cloudtrail_log_bucket_name       = "abutech-amexsec-log-archive-368351959735"
  cloudtrail_log_prefix            = "org-cloudtrail"
  cloudtrail_kms_key_arn           = ""
  cloudtrail_include_global_events = true
  cloudtrail_multi_region          = true
  cloudtrail_log_file_validation   = true
  cloudtrail_s3_data_events        = false
  cloudtrail_lambda_data_events    = false

  # Config aggregator — pulls from all accounts
  enable_config_aggregator  = true
  config_aggregator_regions = ["us-east-1"]

  # Root account protection
  enable_root_usage_alarm = true
  security_alert_email    = "emaina@arizona.edu"

  # IAM password policy
  password_minimum_length        = 14
  password_max_age_days          = 90
  password_reuse_prevention      = 24
  password_require_uppercase     = true
  password_require_lowercase     = true
  password_require_numbers       = true
  password_require_symbols       = true
  allow_users_to_change_password = true
  hard_expiry                    = false

  common_tags = var.common_tags

  depends_on = [aws_s3_bucket_policy.cloudtrail_log_archive]
}
# ============================================================
# MODULE CALL — iam-identity-center
# Phase 1, Module 3 — SCPs + Permission Sets + Break Glass
# Entra ID SAML + SCIM configured manually (see docs/)
# ============================================================
module "iam_identity_center" {
  source = "../../modules/iam-identity-center"

  aws_region                  = var.aws_region
  project_prefix              = var.project_prefix
  management_account_id       = var.management_account_id
  security_tooling_account_id = var.security_tooling_account_id
  audit_account_id            = "445459853572"

  # OU IDs from aws-organization module
  root_id              = module.aws_organization.root_id
  security_ou_id       = module.aws_organization.security_ou_id
  production_ou_id     = module.aws_organization.production_ou_id
  non_production_ou_id = module.aws_organization.non_production_ou_id
  compliance_ou_id     = module.aws_organization.compliance_ou_id
  pipeline_ou_id       = module.aws_organization.pipeline_ou_id

  # Deploy Permission Sets and SCPs
  deploy_identity_center = true
  deploy_scps            = true

  # Entra ID connected manually via console
  # See docs/entra-id-integration.md for details
  deploy_entra_id_connection = false
  entra_tenant_id            = "288a15d1-700c-482b-a591-7c1d4e6c4f3c"
  entra_idp_sign_in_url      = "https://login.microsoftonline.com/288a15d1-700c-482b-a591-7c1d4e6c4f3c/saml2"
  entra_idp_issuer_url       = "https://sts.windows.net/288a15d1-700c-482b-a591-7c1d4e6c4f3c/"

  # Session durations
  security_auditor_session_hours = 8
  developer_session_hours        = 4
  network_admin_session_hours    = 4
  break_glass_session_hours      = 1
  occ_examiner_session_hours     = 8

  # Break Glass alerts
  break_glass_alert_email   = "emaina@arizona.edu"
  break_glass_sns_topic_arn = ""

  # Approved regions
  approved_regions = ["us-east-1", "us-west-2"]

  common_tags = var.common_tags
}

# ============================================================
# MODULE CALL — audit-account
# Phase 1, Module 4 — cross-account read-only roles for OCC
# examiners, deployed into Management and Security Tooling.
# ============================================================
module "audit_account" {
  source = "../../modules/audit-account"

  providers = {
    aws.management       = aws
    aws.security_tooling = aws.security_tooling
  }

  aws_region                  = var.aws_region
  project_prefix              = var.project_prefix
  audit_account_id            = "445459853572"
  management_account_id       = var.management_account_id
  security_tooling_account_id = var.security_tooling_account_id

  create_management_audit_role       = true
  create_security_tooling_audit_role = true

  common_tags = var.common_tags
}

output "audit_role_arns" {
  description = "Cross-account AuditReadOnly role ARNs"
  value = {
    management       = module.audit_account.audit_role_arn_management
    security_tooling = module.audit_account.audit_role_arn_security_tooling
  }
}

output "occ_examination_guide" {
  description = "How OCC examiners access each account"
  value       = module.audit_account.occ_examination_guide
}

output "permission_sets" {
  description = "Deployed Permission Set ARNs"
  value       = module.iam_identity_center.permission_set_arns
}

output "scp_ids" {
  description = "Deployed SCP IDs"
  value       = module.iam_identity_center.scp_ids
}

output "sso_portal_url" {
  description = "SSO login portal URL"
  value       = module.iam_identity_center.sso_portal_url
}

output "next_steps" {
  description = "Next configuration steps"
  value       = module.iam_identity_center.next_steps
}

# ============================================================
# MANAGEMENT BASELINE OUTPUTS
# ============================================================
output "org_cloudtrail_arn" {
  description = "Organization-wide CloudTrail ARN"
  value       = module.management_baseline.org_cloudtrail_arn
}

output "config_aggregator_arn" {
  description = "Config aggregator ARN"
  value       = module.management_baseline.config_aggregator_arn
}

output "baseline_status" {
  description = "Management baseline component status"
  value       = module.management_baseline.baseline_status
}

output "occ_evidence" {
  description = "OCC examination evidence provided by this baseline"
  value       = module.management_baseline.occ_evidence_note
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