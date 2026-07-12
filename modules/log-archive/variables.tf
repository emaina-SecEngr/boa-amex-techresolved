# ============================================================
# variables.tf — Module input variables
# Module: log-archive
#
# WHAT THIS MODULE BUILDS:
# Production-grade immutable log archive in Security Tooling
# account. All security logs from all accounts flow here.
#
# WHY LOG ARCHIVE IS FIRST IN PHASE 2:
# Every other Phase 2 module needs somewhere to send logs.
# GuardDuty findings, CloudTrail events, VPC Flow Logs,
# Security Hub findings — all need this bucket to exist
# before they can be configured to deliver.
#
# KEY FEATURES:
# 1. Object Lock WORM — logs cannot be deleted or modified
#    Required by PCI-DSS and OCC for immutable audit trail
#
# 2. KMS encryption with CMK — logs encrypted at rest
#    Key rotation enabled, access logged in CloudTrail
#
# 3. Lifecycle policies — cost optimization
#    0-90 days: S3 Standard (fast access for investigation)
#    90-365 days: S3 Glacier Instant Retrieval
#    365+ days: S3 Glacier Deep Archive (cheapest)
#    7 years total retention (OCC requirement)
#
# 4. Cross-account delivery — accepts logs from all accounts
#    S3 bucket policy allows CloudTrail, GuardDuty, Config
#    from any account in the Organization to write here
#
# SENTINEL INTEGRATION:
# Security Lake sits on top of this bucket and normalizes
# logs to OCSF format for Sentinel ingestion.
# Toggle: enable_sentinel_integration = false until ready
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
  description = "Security Tooling account ID where log archive lives."
  type        = string
  default     = "368351959735"
}

variable "management_account_id" {
  description = "Management account ID — allowed to write org CloudTrail."
  type        = string
  default     = "682391277575"
}

variable "organization_id" {
  description = "AWS Organization ID — all member accounts allowed to write logs."
  type        = string
  default     = "o-tlzn7g9bvb"
}

# -----------------------------------------------------------
# BUCKET CONFIGURATION
# -----------------------------------------------------------
variable "log_archive_bucket_name" {
  description = "S3 bucket name for log archive. Must be globally unique. Convention: project-log-archive-account-id."
  type        = string
  default     = "boa-amex-log-archive-368351959735"
}

variable "enable_object_lock" {
  description = "Enable S3 Object Lock for WORM immutability. Required for PCI-DSS and OCC compliance. Cannot be disabled after bucket creation."
  type        = bool
  default     = true
}

variable "object_lock_retention_days" {
  description = "Object Lock retention period in days. OCC requires 7 years minimum = 2555 days. Set to COMPLIANCE mode — even the bucket owner cannot delete before expiry."
  type        = number
  default     = 2555
}

variable "enable_versioning" {
  description = "Enable S3 versioning. Required for Object Lock. Also provides protection against accidental overwrites."
  type        = bool
  default     = true
}

# -----------------------------------------------------------
# LIFECYCLE POLICY
# Controls how logs move between storage tiers over time
# Balances access speed vs cost
# -----------------------------------------------------------
variable "standard_retention_days" {
  description = "Days to keep logs in S3 Standard (fast, expensive). Active investigation window — security team needs fast access."
  type        = number
  default     = 90
}

variable "glacier_instant_retention_days" {
  description = "Days to keep logs in Glacier Instant Retrieval (millisecond access, cheaper). Compliance review window."
  type        = number
  default     = 365
}

variable "glacier_deep_archive_retention_days" {
  description = "Days to keep logs in Glacier Deep Archive (cheapest, 12-hour retrieval). Long-term retention for regulatory requirements."
  type        = number
  default     = 2555
}

# -----------------------------------------------------------
# KMS ENCRYPTION
# -----------------------------------------------------------
variable "kms_key_deletion_window_days" {
  description = "KMS key deletion window in days. Minimum 7, maximum 30. 30 days gives maximum recovery window if key is accidentally scheduled for deletion."
  type        = number
  default     = 30
}

variable "kms_key_rotation_enabled" {
  description = "Enable automatic KMS key rotation annually. PCI-DSS Requirement 3.7: cryptographic key rotation."
  type        = bool
  default     = true
}

# -----------------------------------------------------------
# LOG SOURCES
# Which AWS services are allowed to write to this bucket
# -----------------------------------------------------------
variable "enable_cloudtrail_delivery" {
  description = "Allow CloudTrail from all Organization accounts to deliver logs here."
  type        = bool
  default     = true
}

variable "enable_guardduty_delivery" {
  description = "Allow GuardDuty findings export to this bucket."
  type        = bool
  default     = true
}

variable "enable_config_delivery" {
  description = "Allow AWS Config snapshots and history to deliver here."
  type        = bool
  default     = true
}

variable "enable_vpc_flow_logs_delivery" {
  description = "Allow VPC Flow Logs from all accounts to deliver here."
  type        = bool
  default     = true
}

variable "enable_security_hub_delivery" {
  description = "Allow Security Hub findings export to this bucket."
  type        = bool
  default     = true
}

# -----------------------------------------------------------
# SENTINEL INTEGRATION TOGGLE
# Set false now — flip to true when Azure account is fixed
# -----------------------------------------------------------
variable "enable_sentinel_integration" {
  description = "Enable Microsoft Sentinel integration via Security Lake. Set false until Azure subscription is active. When true, requires sentinel_workspace_id and sentinel_workspace_key."
  type        = bool
  default     = false
}

variable "sentinel_workspace_id" {
  description = "Microsoft Sentinel Log Analytics workspace ID. Required when enable_sentinel_integration = true. Get from Azure Portal → Sentinel → Settings → Workspace settings."
  type        = string
  default     = ""
  sensitive   = true
}

variable "sentinel_workspace_key" {
  description = "Microsoft Sentinel Log Analytics primary key. Required when enable_sentinel_integration = true. Get from Azure Portal → Log Analytics → Agents → Primary key."
  type        = string
  default     = ""
  sensitive   = true
}

variable "sentinel_data_collection_endpoint" {
  description = "Azure Monitor Data Collection Endpoint URL. Required when enable_sentinel_integration = true."
  type        = string
  default     = ""
}

# -----------------------------------------------------------
# ALERTING
# -----------------------------------------------------------
variable "security_alert_email" {
  description = "Email for security alerts including unauthorized log access attempts."
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
    Module          = "log-archive"
  }
}