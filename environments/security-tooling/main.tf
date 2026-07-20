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

# ============================================================
# MODULE CALL — wiz
# Phase 2, Module 6 — CNAPP agentless scanning
#
# TRIAL: Contact sales@wiz.io for 30-day free trial
# Once trial active:
#   1. Get wiz_aws_account_id from Wiz connector setup
#   2. Get wiz_external_id from Wiz connector setup
#   3. Update terraform.tfvars with values
#   4. terraform apply
#   5. Paste WizScanner role ARN into Wiz console
# ============================================================
module "wiz" {
  source = "../../modules/wiz"

  aws_region                  = var.aws_region
  project_prefix              = var.project_prefix
  security_tooling_account_id = var.security_tooling_account_id
  organization_id             = var.organization_id

  # Wiz connector — values from Wiz onboarding
  wiz_aws_account_id = "197857026523"
  wiz_external_id    = "WIZ-BOA-AMEX-SCANNER"
  wiz_tenant_id      = ""
  enable_wiz_scanner = true

  # Scanning capabilities
  enable_cspm_scanning       = true
  enable_cwpp_scanning       = true
  enable_ciem_scanning       = true
  enable_data_scanning       = true
  enable_kubernetes_scanning = false

  # KMS grants for encrypted volume scanning
  enable_kms_grants       = true
  log_archive_kms_key_arn = module.log_archive.log_archive_kms_key_arn

  # Findings integration
  enable_findings_integration = false
  findings_webhook_secret     = ""

  security_alert_email = var.security_alert_email
  common_tags          = var.common_tags

  depends_on = [
    module.log_archive
  ]
}

# ============================================================
# MODULE CALL — crowdstrike
# Phase 3, Module 1 — endpoint detection and response
#
# TOGGLE: enable_crowdstrike = false
# Enable when CrowdStrike trial/subscription active
# Get CID from: Falcon console → Host Setup → Sensor Downloads
# ============================================================
module "crowdstrike" {
  source = "../../modules/crowdstrike"

  aws_region                  = var.aws_region
  project_prefix              = var.project_prefix
  security_tooling_account_id = var.security_tooling_account_id
  organization_id             = var.organization_id

  log_archive_kms_key_arn = module.log_archive.log_archive_kms_key_arn

  # Master toggle — false until trial active
  enable_crowdstrike = false

  # CrowdStrike account config — from onboarding
  crowdstrike_cid            = ""
  crowdstrike_aws_account_id = "292230061137"
  crowdstrike_external_id    = ""

  # Sensor deployment
  enable_sensor_deployment = true
  sensor_version           = "Latest"
  sensor_target_platform   = "Linux"
  ssm_association_schedule = "cron(0 2 * * ? *)"

  # Falcon Horizon CSPM
  enable_falcon_horizon = true

  # FDR telemetry streaming
  enable_fdr         = true
  fdr_bucket_name    = "boa-amex-crowdstrike-fdr-368351959735"
  fdr_retention_days = 90

  # Detection modules
  enable_edr                 = true
  enable_identity_protection = true
  enable_container_security  = false

  # Alerting
  critical_detection_threshold = 4
  security_alert_email         = var.security_alert_email
  security_alert_topic_arn     = ""

  # Sentinel — disabled until Azure subscription fixed
  enable_sentinel_integration = false

  common_tags = var.common_tags

  depends_on = [module.log_archive]
}

# ============================================================
# MODULE CALL — palo-alto
# Phase 3, Module 2 — network inspection (Palo Alto + AWS NFW)
#
# ALL TOGGLES OFF BY DEFAULT:
#   enable_palo_alto = false ($1,440+/month)
#   enable_aws_network_firewall = false ($285/month)
#   enable_transit_gateway = false ($36/month)
# ============================================================
module "palo_alto" {
  source = "../../modules/palo-alto"

  aws_region                  = var.aws_region
  project_prefix              = var.project_prefix
  security_tooling_account_id = var.security_tooling_account_id
  organization_id             = var.organization_id

  # All toggled off — enable for demos
  enable_palo_alto            = false
  enable_aws_network_firewall = false
  enable_transit_gateway      = false

  # Security VPC config (ready when toggled on)
  security_vpc_cidr       = "10.0.0.0/16"
  inspection_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  management_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
  availability_zones      = ["us-east-1a", "us-east-1b"]

  # Palo Alto config (when enabled)
  palo_alto_ami_id         = ""
  palo_alto_instance_type  = "m5.xlarge"
  palo_alto_instance_count = 2
  panorama_server          = ""
  panorama_device_group    = "BOA-AMEX-AWS"

  # Network Firewall config (when enabled)
  enable_suricata_rules = true
  blocked_domains = [
    "*.tor2web.com",
    "*.onion.to",
    "pastebin.com",
    "*.duckdns.org",
    "*.no-ip.com"
  ]

  # Logging
  log_archive_bucket_name = module.log_archive.log_archive_bucket_name
  log_archive_kms_key_arn = module.log_archive.log_archive_kms_key_arn
  enable_flow_logs        = true
  enable_firewall_logs    = true

  # Sentinel
  enable_sentinel_integration = false

  security_alert_email = var.security_alert_email
  common_tags          = var.common_tags

  depends_on = [module.log_archive]
}

# ============================================================
# MODULE CALL — sentinel
# Phase 3, Module 3 — Microsoft Sentinel SIEM connector
#
# TOGGLE: enable_sentinel = false
# Enable when Azure student subscription is restored
# See: module.sentinel.sentinel_activation_instructions
# ============================================================
module "sentinel" {
  source = "../../modules/sentinel"

  aws_region                  = var.aws_region
  project_prefix              = var.project_prefix
  security_tooling_account_id = var.security_tooling_account_id
  organization_id             = var.organization_id

  # Master toggle — false until Azure is fixed
  enable_sentinel = false

  # Sentinel workspace — fill when Azure restored
  sentinel_workspace_id    = ""
  sentinel_workspace_key   = ""
  sentinel_azure_tenant_id = "288a15d1-700c-482b-a591-7c1d4e6c4f3c"

  # Data source connectors
  enable_cloudtrail_connector    = true
  enable_guardduty_connector     = true
  enable_security_hub_connector  = true
  enable_vpc_flow_logs_connector = true
  enable_waf_connector           = false

  # S3 references
  log_archive_bucket_name = module.log_archive.log_archive_bucket_name
  log_archive_bucket_arn  = module.log_archive.log_archive_bucket_arn
  log_archive_kms_key_arn = module.log_archive.log_archive_kms_key_arn

  security_alert_email = var.security_alert_email
  common_tags          = var.common_tags

  depends_on = [module.log_archive]
}

# ============================================================
# MODULE CALL — soar
# Phase 4 — automated incident response (40 playbooks)
#
# 8 EventBridge rules route findings to Lambda dispatcher
# Lambda routes to correct playbook based on finding type
# ============================================================
module "soar" {
  source = "../../modules/soar"

  aws_region                  = var.aws_region
  project_prefix              = var.project_prefix
  security_tooling_account_id = var.security_tooling_account_id
  management_account_id       = var.management_account_id
  organization_id             = var.organization_id
  audit_account_id            = var.audit_account_id

  # Master toggle
  enable_soar = true

  # Playbook categories
  enable_infrastructure_playbooks    = true
  enable_iam_playbooks               = true
  enable_token_playbooks             = true
  enable_container_playbooks         = false
  enable_network_playbooks           = true
  enable_runtime_playbooks           = true
  enable_vulnerability_playbooks     = true
  enable_data_exfiltration_playbooks = true

  # Response mode
  response_mode            = "AUTO"
  approval_timeout_minutes = 15

  # References from other modules
  log_archive_bucket_name = module.log_archive.log_archive_bucket_name
  log_archive_kms_key_arn = module.log_archive.log_archive_kms_key_arn
  guardduty_detector_id   = module.guardduty.detector_id
  security_hub_arn        = module.security_hub.security_hub_arn

  # Quarantine and forensics — empty for now
  quarantine_vpc_id     = ""
  forensics_bucket_name = ""

  # Alerting
  security_alert_email     = var.security_alert_email
  critical_alert_email     = var.security_alert_email
  existing_alert_topic_arn = ""

  # Sentinel
  enable_sentinel_integration = false

  common_tags = var.common_tags

  depends_on = [module.guardduty, module.security_hub]
}

# ============================================================
# MODULE CALL — config-conformance-packs
# Phase 6 — org-wide Config conformance packs (PCI-DSS,
# NIST 800-53). Definition only — deploy_conformance_packs
# stays false until AWS Config recording is enabled per-account
# in a later phase, otherwise these produce no evaluations.
# ============================================================
module "config_conformance_packs" {
  source = "../../modules/config-conformance-packs"

  project_prefix           = var.project_prefix
  deploy_conformance_packs = false
  common_tags              = var.common_tags
}

# ============================================================
# MODULE CALL — ai-security-agent
# Bedrock-backed triage of GuardDuty/Security Hub findings,
# with action authority to invoke SOAR playbooks. allowed_playbooks
# starts empty — the agent triages and alerts on everything, but
# cannot invoke SOAR until specific playbooks are authorized here.
# PREREQUISITE: Bedrock model access must be requested/approved in
# the AWS Console for this account before InvokeModel succeeds.
# ============================================================
module "ai_security_agent" {
  source = "../../modules/ai-security-agent"

  aws_region                  = var.aws_region
  project_prefix              = var.project_prefix
  security_tooling_account_id = var.security_tooling_account_id
  management_account_id       = var.management_account_id
  organization_id             = var.organization_id
  audit_account_id            = var.audit_account_id

  enable_ai_security_agent = true

  bedrock_model_id          = "anthropic.claude-sonnet-4-5-20250929-v1:0"
  triage_severity_threshold = 4.0

  enable_autonomous_response = true
  allowed_playbooks          = []

  soar_dispatcher_arn = module.soar.soar_dispatcher_arn

  security_alert_email = var.security_alert_email
  common_tags          = var.common_tags

  depends_on = [module.soar, module.guardduty, module.security_hub]
}
