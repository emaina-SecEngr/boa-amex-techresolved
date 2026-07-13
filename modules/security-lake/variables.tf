# ============================================================
# variables.tf — Module input variables
# Module: security-lake
#
# WHAT THIS MODULE BUILDS:
# Amazon Security Lake — OCSF normalization layer that
# converts all AWS security logs to a standard format
# for Microsoft Sentinel ingestion.
#
# THREE COMPONENTS:
# 1. Security Lake data lake
#    S3-based storage in OCSF format
#    Receives logs from all AWS sources automatically
#
# 2. Log sources
#    CloudTrail, VPC Flow Logs, Security Hub findings
#    Route 53 resolver logs
#    All automatically normalized to OCSF
#
# 3. Sentinel subscriber (toggled off until Azure fixed)
#    Grants Sentinel permission to read from Security Lake
#    Polls S3 every 5 minutes for new findings
#    One connection replaces 5+ individual connectors
#
# SENTINEL INTEGRATION:
#    enable_sentinel_integration = false (now)
#    Flip to true when Azure subscription restored
#    Provide sentinel_external_id from Azure connector
#
# COST: ~$0.25/GB normalized
#       Sandbox estimate: ~$15-30/month
#       Most expensive Phase 2 resource
# ============================================================

variable "aws_region" {
  description = "Primary AWS region."
  type        = string
  default     = "us-east-1"
}

variable "project_prefix" {
  description = "Short prefix for resource naming."
  type        = string
  default     = "boa-amex"
}

variable "security_tooling_account_id" {
  description = "Security Tooling account ID — Security Lake deployed here."
  type        = string
  default     = "368351959735"
}

variable "management_account_id" {
  description = "Management account ID."
  type        = string
  default     = "682391277575"
}

variable "organization_id" {
  description = "AWS Organization ID."
  type        = string
  default     = "o-tlzn7g9bvb"
}

variable "log_archive_kms_key_arn" {
  description = "KMS key ARN for Security Lake encryption. From log-archive module."
  type        = string
  default     = ""
}

# -----------------------------------------------------------
# SECURITY LAKE CONFIGURATION
# -----------------------------------------------------------
variable "enable_security_lake" {
  description = "Enable Amazon Security Lake."
  type        = bool
  default     = true
}

variable "security_lake_retention_days" {
  description = "Days to retain data in Security Lake S3. After this period data moves to transition storage class."
  type        = number
  default     = 365
}

variable "security_lake_transition_days" {
  description = "Days before transitioning Security Lake data to cheaper storage."
  type        = number
  default     = 90
}

# -----------------------------------------------------------
# LOG SOURCES
# Each source automatically normalizes to OCSF format
# -----------------------------------------------------------
variable "enable_cloudtrail_source" {
  description = "Ingest CloudTrail management events into Security Lake. Provides complete API activity in OCSF format."
  type        = bool
  default     = true
}

variable "enable_vpc_flow_logs_source" {
  description = "Ingest VPC Flow Logs into Security Lake. Network traffic normalized to OCSF format."
  type        = bool
  default     = true
}

variable "enable_security_hub_source" {
  description = "Ingest Security Hub findings into Security Lake. All compliance and threat findings in OCSF format."
  type        = bool
  default     = true
}

variable "enable_route53_source" {
  description = "Ingest Route 53 resolver query logs into Security Lake. DNS activity in OCSF format."
  type        = bool
  default     = true
}

variable "enable_lambda_source" {
  description = "Ingest Lambda execution logs into Security Lake."
  type        = bool
  default     = false
}

# -----------------------------------------------------------
# SENTINEL SUBSCRIBER
# Grants Sentinel permission to read from Security Lake
# Toggle false until Azure subscription is restored
# -----------------------------------------------------------
variable "enable_sentinel_integration" {
  description = "Create Sentinel subscriber in Security Lake. Set false until Azure subscription is active. When true requires sentinel_external_id."
  type        = bool
  default     = false
}

variable "sentinel_external_id" {
  description = "External ID from Microsoft Sentinel AWS S3 connector. Found in Azure Portal → Sentinel → Data Connectors → Amazon Web Services S3. Required when enable_sentinel_integration = true."
  type        = string
  default     = ""
  sensitive   = true
}

# NOTE: no sentinel_sqs_queue_arn variable here. The SQS queue created by
# aws_securitylake_subscriber_notification's sqs_notification_configuration
# block is provisioned server-side by AWS and the Terraform resource
# schema does not expose its ARN/URL as a computed attribute — there is
# nothing for this variable to hold in either direction. Retrieve the
# queue URL from the AWS console (Security Lake -> Subscribers) or
# `aws securitylake get-subscriber` when connecting Sentinel.

# -----------------------------------------------------------
# ORG-WIDE CONFIGURATION
# Security Lake has no dedicated org-wide auto-enable resource
# (unlike GuardDuty/Security Hub) — member_accounts is folded into
# each log source's `accounts` set instead. New accounts added to
# the Organization later are NOT automatically covered; add them
# to member_accounts and re-apply.
# -----------------------------------------------------------
variable "enable_org_sources" {
  description = "Include member_accounts in every log source's accounts set, so their logs are also ingested into this Security Lake instance."
  type        = bool
  default     = true
}

variable "member_accounts" {
  description = "Member account IDs to enable as Security Lake sources, in addition to the Security Tooling account itself."
  type        = list(string)
  default     = ["445459853572"]
}

variable "security_alert_email" {
  description = "Email for Security Lake alerts."
  type        = string
  default     = "emaina@arizona.edu"
}

variable "common_tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default = {
    Project         = "BOA-AMEX-TechResolved"
    Owner           = "Eliud-Maina"
    Consultant      = "Abuhari-Consulting-Services"
    ManagedBy       = "Terraform"
    ComplianceScope = "PCI-DSS-v4 OCC-12CFR30 NIST-800-53"
    Phase           = "2-SecurityTooling"
    Module          = "security-lake"
  }
}