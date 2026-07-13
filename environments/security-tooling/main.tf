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
    bucket       = "abuhari-terraform-state-368351959735"
    key          = "boa-amex/security-tooling/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
    profile      = "security-tooling"
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

# ============================================================
# MODULE CALL — guardduty
# Phase 2, Module 2 — org-wide threat detection
#
# IMPORT REQUIRED before first apply:
#   cd environments/security-tooling
#   terraform import module.guardduty.aws_guardduty_detector.main \
#     b6cf6963ce4553017b19d5bb98e6b209
# ============================================================
module "guardduty" {
  source = "../../modules/guardduty"

  aws_region                  = var.aws_region
  project_prefix              = var.project_prefix
  security_tooling_account_id = var.security_tooling_account_id
  management_account_id       = var.management_account_id
  organization_id             = var.organization_id
  audit_account_id            = var.audit_account_id

  # Existing detector — imported not created
  existing_detector_id = "b6cf6963ce4553017b19d5bb98e6b209"

  # Detector configuration
  enable_guardduty             = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"

  # Protection plans
  # guardduty:UpdateDetector is no longer denied by the
  # DenyDisablingSecurity SCP (p-qondnimf) — see modules/iam-identity-center/scps.tf
  enable_s3_protection      = true
  enable_eks_protection     = true
  enable_malware_protection = true
  enable_rds_protection     = true
  enable_lambda_protection  = true
  enable_runtime_monitoring = false

  # Findings export to log archive
  enable_findings_export  = true
  log_archive_bucket_name = module.log_archive.log_archive_bucket_name
  log_archive_kms_key_arn = module.log_archive.log_archive_kms_key_arn

  # Org-wide auto-enable
  enable_org_auto_enable = true
  # Empty — org auto-enable (enable_org_auto_enable) already covers
  # every member account, including Audit. Manual invite via
  # member_accounts conflicts with autoEnableOrganizationMembers=ALL
  # and AWS rejects it outright.
  member_accounts = []

  # Alerting
  high_severity_threshold  = 7.0
  security_alert_topic_arn = ""
  security_alert_email     = var.security_alert_email

  # Sentinel — disabled until Azure subscription fixed
  enable_sentinel_integration = false

  common_tags = var.common_tags

  depends_on = [module.log_archive]
}

# ============================================================
# MODULE CALL — security_hub
# Phase 2 — Security Hub as the org-wide findings aggregator
#
# PREREQUISITE: guardduty module complete (detector referenced
# below)
# ============================================================
module "security_hub" {
  source = "../../modules/security-hub"

  aws_region                  = var.aws_region
  project_prefix              = var.project_prefix
  security_tooling_account_id = var.security_tooling_account_id
  management_account_id       = var.management_account_id
  organization_id             = var.organization_id
  audit_account_id            = var.audit_account_id

  enable_security_hub       = true
  auto_enable_controls      = true
  control_finding_generator = "SECURITY_CONTROL"

  # Compliance standards
  enable_cis_standard              = true
  enable_pci_dss_standard          = true
  enable_aws_foundational_standard = true
  enable_nist_standard             = false

  # Cross-account finding aggregation
  enable_finding_aggregation = true

  # Org-wide auto-enable for new accounts
  enable_org_auto_enable = true

  # Alerting — EventBridge rule fires for this severity and above
  critical_finding_threshold = "CRITICAL"
  security_alert_email       = var.security_alert_email

  # Sentinel — disabled until Azure subscription fixed
  enable_sentinel_integration = false

  common_tags = var.common_tags

  depends_on = [module.log_archive, module.guardduty]
}

# ============================================================
# MODULE CALL — detective
# Phase 2, Module 4 — behavior graph for investigation
#
# IMPORT REQUIRED before first apply:
#   terraform import module.detective.aws_detective_graph.main \
#     arn:aws:detective:us-east-1:368351959735:graph:97cadf0d24b147f0bfd76cfac41ea1a1
# ============================================================
module "detective" {
  source = "../../modules/detective"

  aws_region                  = var.aws_region
  project_prefix              = var.project_prefix
  security_tooling_account_id = var.security_tooling_account_id
  organization_id             = var.organization_id
  audit_account_id            = var.audit_account_id

  existing_graph_arn = "arn:aws:detective:us-east-1:368351959735:graph:97cadf0d24b147f0bfd76cfac41ea1a1"
  enable_detective   = true

  member_accounts = ["445459853572"]
  member_emails = {
    "445459853572" = "mwangi.maina83+audit@gmail.com"
  }

  enable_org_datasources = true
  security_alert_email   = var.security_alert_email
  common_tags            = var.common_tags

  depends_on = [module.guardduty]
}

# ============================================================
# MODULE CALL — security_lake
# Phase 2, Module 5 — OCSF normalization layer for Sentinel
#
# PREREQUISITE: log-archive, guardduty, security_hub complete
# No import required — fresh resource, not pre-existing.
# ============================================================
module "security_lake" {
  source = "../../modules/security-lake"

  aws_region                  = var.aws_region
  project_prefix              = var.project_prefix
  security_tooling_account_id = var.security_tooling_account_id
  management_account_id       = var.management_account_id
  organization_id             = var.organization_id

  # Security Lake configuration
  enable_security_lake          = false
  security_lake_retention_days  = 365
  security_lake_transition_days = 90

  # Log sources
  enable_cloudtrail_source    = true
  enable_vpc_flow_logs_source = true
  enable_security_hub_source  = true
  enable_route53_source       = true
  enable_lambda_source        = false

  # Org-wide sources — folds member_accounts into every log source
  enable_org_sources = true
  member_accounts    = ["445459853572"]

  # Sentinel — disabled until Azure subscription fixed
  enable_sentinel_integration = false
  sentinel_external_id        = ""

  log_archive_kms_key_arn = module.log_archive.log_archive_kms_key_arn
  security_alert_email    = var.security_alert_email
  common_tags             = var.common_tags

  depends_on = [module.log_archive, module.guardduty, module.security_hub]
}
