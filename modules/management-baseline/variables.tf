# ============================================================
# variables.tf — Module input variables
# Module: management-baseline
#
# WHAT THIS MODULE BUILDS:
# The minimum security configuration that must exist in the
# Management account before any workload is built anywhere
# in the Organization.
#
# FOUR COMPONENTS:
# 1. Org-wide CloudTrail — captures ALL API events from
#    ALL accounts, managed from Management, cannot be
#    disabled by member account administrators
#
# 2. Config Aggregator — pulls compliance data from ALL
#    accounts into one central view in Management account
#    OCC examiners see complete compliance posture here
#
# 3. Root Account Protection — MFA enforcement + alarm
#    that fires the moment root credentials are used
#    anywhere in the Organization
#
# 4. IAM Password Policy — minimum password requirements
#    for all IAM users in the Management account
#    (Identity Center handles workload account identity)
#
# WHY THIS COMES BEFORE EVERYTHING ELSE:
# Without org-wide CloudTrail, the build process itself
# is not auditable. OCC examiners can ask "what happened
# during Days 1-14 before you enabled logging?" and the
# answer cannot be "nothing" if logging didn't exist.
# Management Baseline ensures every action from day one
# is recorded, immutable, and independently verifiable.
#
# DEPLOYMENT ORDER:
# Runs in Management account (682391277575)
# Requires: aws-organization module complete (OUs must exist)
# Required by: ALL other modules (must be first)
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

variable "management_account_id" {
  description = "Management account ID (682391277575)."
  type        = string
  default     = "682391277575"
}

variable "security_tooling_account_id" {
  description = "Security Tooling account ID (368351959735). CloudTrail logs delivered here."
  type        = string
  default     = "368351959735"
}

variable "organization_id" {
  description = "AWS Organization ID (o-tlzn7g9bvb)."
  type        = string
  default     = "o-tlzn7g9bvb"
}

# -----------------------------------------------------------
# ORG-WIDE CLOUDTRAIL CONFIGURATION
# -----------------------------------------------------------
variable "enable_org_cloudtrail" {
  description = "Enable organization-wide CloudTrail. Captures ALL API events from ALL accounts. Managed from Management account — cannot be disabled by member accounts. Should always be true in production."
  type        = bool
  default     = true
}

variable "cloudtrail_log_bucket_name" {
  description = "S3 bucket name in Security Tooling account where org-wide CloudTrail logs are delivered. This bucket must already exist (created by Phase 2 log-archive module) OR we use the existing amex-log-archive bucket."
  type        = string
  default     = "abutech-amexsec-log-archive-368351959735"
}

variable "cloudtrail_log_prefix" {
  description = "S3 key prefix for org-wide CloudTrail logs. Separates org trail logs from account-specific logs in the same bucket."
  type        = string
  default     = "org-cloudtrail"
}

variable "cloudtrail_kms_key_arn" {
  description = "KMS key ARN in Security Tooling account for CloudTrail log encryption. Leave empty to use default CloudTrail encryption (SSE-S3). Production should always use CMK."
  type        = string
  default     = ""
}

variable "cloudtrail_include_global_events" {
  description = "Include global service events (IAM, STS, Route 53) in CloudTrail. Must be true for PCI-DSS compliance — IAM events are the most security-critical."
  type        = bool
  default     = true
}

variable "cloudtrail_multi_region" {
  description = "Enable multi-region CloudTrail. Captures events from ALL regions, not just us-east-1. Required to detect attacks that use non-primary regions to evade detection."
  type        = bool
  default     = true
}

variable "cloudtrail_log_file_validation" {
  description = "Enable CloudTrail log file validation via SHA-256 hashing. Creates a digest file allowing detection of log tampering. Required for OCC and PCI-DSS."
  type        = bool
  default     = true
}

variable "cloudtrail_s3_data_events" {
  description = "Enable S3 data event logging (GetObject, PutObject, DeleteObject). Significantly increases CloudTrail cost at scale — toggle based on compliance requirement. Required for PCI-DSS if S3 stores cardholder data."
  type        = bool
  default     = false
}

variable "cloudtrail_lambda_data_events" {
  description = "Enable Lambda data event logging (Invoke). Increases cost — enable when Lambda functions process sensitive data."
  type        = bool
  default     = false
}

# -----------------------------------------------------------
# CONFIG AGGREGATOR CONFIGURATION
# -----------------------------------------------------------
variable "enable_config_aggregator" {
  description = "Enable organization-wide Config aggregator. Pulls compliance data from ALL accounts into Management account. OCC examiners see complete posture from one view."
  type        = bool
  default     = true
}

variable "config_aggregator_regions" {
  description = "Regions to aggregate Config data from. Default includes us-east-1 only — add regions as workloads expand."
  type        = list(string)
  default     = ["us-east-1"]
}

# -----------------------------------------------------------
# ROOT ACCOUNT PROTECTION
# -----------------------------------------------------------
variable "enable_root_usage_alarm" {
  description = "Create CloudWatch alarm that fires immediately when root account credentials are used anywhere in the Organization. Sends SNS notification to security team."
  type        = bool
  default     = true
}

variable "security_alert_email" {
  description = "Email address for security alerts including root account usage notifications."
  type        = string
  default     = "emaina@arizona.edu"
}

# -----------------------------------------------------------
# IAM PASSWORD POLICY
# Management account IAM password policy.
# Note: IAM Identity Center (Phase 1 Module 3) handles
# password policy for workload account access via Entra ID.
# This policy covers IAM users IN the Management account only.
# -----------------------------------------------------------
variable "password_minimum_length" {
  description = "Minimum IAM password length. PCI-DSS requires minimum 12 characters. We set 14 for additional margin."
  type        = number
  default     = 14
}

variable "password_max_age_days" {
  description = "Maximum IAM password age in days. PCI-DSS Requirement 8.3.9 requires passwords changed at least every 90 days."
  type        = number
  default     = 90
}

variable "password_reuse_prevention" {
  description = "Number of previous passwords that cannot be reused. PCI-DSS requires minimum 4. We set 24 (2 years of quarterly changes)."
  type        = number
  default     = 24
}

variable "password_require_uppercase" {
  description = "Require uppercase letters in passwords."
  type        = bool
  default     = true
}

variable "password_require_lowercase" {
  description = "Require lowercase letters in passwords."
  type        = bool
  default     = true
}

variable "password_require_numbers" {
  description = "Require numbers in passwords."
  type        = bool
  default     = true
}

variable "password_require_symbols" {
  description = "Require symbols in passwords."
  type        = bool
  default     = true
}

variable "allow_users_to_change_password" {
  description = "Allow IAM users to change their own passwords. Should be true — prevents helpdesk bottleneck."
  type        = bool
  default     = true
}

variable "hard_expiry" {
  description = "Prevent IAM users from choosing a new password after expiry — requires admin reset. Set false to allow self-service password reset after expiry."
  type        = bool
  default     = false
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
    Phase           = "1-Foundation"
    Module          = "management-baseline"
  }
}