# ============================================================
# variables.tf — Module input variables
# Module: guardduty
#
# WHAT THIS MODULE BUILDS:
# Organization-wide GuardDuty configuration with Security
# Tooling as the delegated administrator. GuardDuty is AWS's
# ML-based threat detection service — it analyzes:
#   - VPC Flow Logs (network traffic patterns)
#   - CloudTrail events (API call patterns)
#   - DNS logs (domain resolution patterns)
#   - S3 data events (data access patterns)
#   - EKS audit logs (container activity)
#   - Malware protection (EC2 + S3 scanning)
#
# EXISTING RESOURCE:
# GuardDuty detector b6cf6963ce4553017b19d5bb98e6b209
# already running in Security Tooling account.
# This module IMPORTS and MANAGES it going forward.
# Run before apply:
#   terraform import module.guardduty.aws_guardduty_detector.main \
#     b6cf6963ce4553017b19d5bb98e6b209
#
# WHY GUARDDUTY CANNOT BE DELETED:
# Our SCP DenyDisablingSecurityServices (p-qondnimf)
# prevents deletion — this is the SCP working correctly.
# OCC requirement: security monitoring must be continuous
# and cannot be disabled by any administrator.
#
# SENTINEL INTEGRATION:
# GuardDuty findings → EventBridge → Lambda → Security Lake
# → Sentinel (when Azure subscription is active)
# Toggle: enable_sentinel_integration = false until ready
#
# WHAT GUARDDUTY DETECTS (examples):
#   Cryptocurrency mining on EC2
#   Credential compromise (unusual API calls)
#   Port scanning from EC2 instances
#   Communication with known C2 servers
#   Data exfiltration to unusual destinations
#   Privilege escalation attempts
#   Lateral movement between services
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
  description = "Security Tooling account ID — GuardDuty delegated admin."
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

variable "audit_account_id" {
  description = "Audit account ID."
  type        = string
  default     = "445459853572"
}

# -----------------------------------------------------------
# EXISTING DETECTOR
# -----------------------------------------------------------
variable "existing_detector_id" {
  description = "Existing GuardDuty detector ID in Security Tooling account. Import this before running terraform apply. Detector ID: b6cf6963ce4553017b19d5bb98e6b209"
  type        = string
  default     = "b6cf6963ce4553017b19d5bb98e6b209"
}

# -----------------------------------------------------------
# DETECTOR CONFIGURATION
# -----------------------------------------------------------
variable "enable_guardduty" {
  description = "Enable GuardDuty detector. Should always be true — SCPs prevent disabling anyway."
  type        = bool
  default     = true
}

variable "finding_publishing_frequency" {
  description = "How often GuardDuty publishes findings. SIX_HOURS for cost optimization in sandbox. FIFTEEN_MINUTES for production (faster detection). ONE_HOUR is a good middle ground."
  type        = string
  default     = "ONE_HOUR"

  validation {
    condition     = contains(["FIFTEEN_MINUTES", "ONE_HOUR", "SIX_HOURS"], var.finding_publishing_frequency)
    error_message = "Must be FIFTEEN_MINUTES, ONE_HOUR, or SIX_HOURS."
  }
}

# -----------------------------------------------------------
# PROTECTION PLANS
# Each adds detection coverage for specific AWS services
# All default to true — defense in depth
# -----------------------------------------------------------
variable "enable_s3_protection" {
  description = "Enable S3 Protection — monitors S3 data events for threats like unusual access patterns, exfiltration, ransomware. PCI-DSS requirement for data at rest protection."
  type        = bool
  default     = true
}

variable "enable_eks_protection" {
  description = "Enable EKS Protection — monitors Kubernetes audit logs for container escape, privilege escalation, cryptomining in containers."
  type        = bool
  default     = true
}

variable "enable_malware_protection" {
  description = "Enable Malware Protection — scans EBS volumes of suspicious EC2 instances for malware. Agentless — no software installed on instances."
  type        = bool
  default     = true
}

variable "enable_rds_protection" {
  description = "Enable RDS Protection — monitors RDS login activity for brute force, credential stuffing, unusual access patterns. Critical for PCI-DSS card data in RDS."
  type        = bool
  default     = true
}

variable "enable_lambda_protection" {
  description = "Enable Lambda Protection — monitors Lambda function network activity for data exfiltration and C2 communication from serverless functions."
  type        = bool
  default     = true
}

variable "enable_runtime_monitoring" {
  description = "Enable Runtime Monitoring — agent-based runtime threat detection for EC2 and ECS. Detects process injection, file system modifications, network connections."
  type        = bool
  default     = false
}

# -----------------------------------------------------------
# FINDINGS EXPORT
# Export findings to S3 for long-term retention and
# Security Lake ingestion → Sentinel
# -----------------------------------------------------------
variable "enable_findings_export" {
  description = "Export GuardDuty findings to S3 log archive. Required for Security Lake ingestion and Sentinel SIEM."
  type        = bool
  default     = true
}

variable "log_archive_bucket_name" {
  description = "S3 bucket name for findings export. From log-archive module output."
  type        = string
  default     = "boa-amex-log-archive-368351959735"
}

variable "log_archive_kms_key_arn" {
  description = "KMS key ARN for encrypting exported findings. From log-archive module output."
  type        = string
  default     = ""
}

# -----------------------------------------------------------
# ORG-WIDE CONFIGURATION
# Auto-enables GuardDuty in all member accounts
# -----------------------------------------------------------
variable "enable_org_auto_enable" {
  description = "Automatically enable GuardDuty in all new accounts added to the Organization. Ensures no account is ever unprotected."
  type        = bool
  default     = true
}

variable "member_accounts" {
  description = "List of member account IDs to enroll in GuardDuty org-wide. These are accounts managed by Security Tooling as delegated admin."
  type        = list(string)
  default     = ["445459853572"]
}

# -----------------------------------------------------------
# ALERTING
# -----------------------------------------------------------
variable "high_severity_threshold" {
  description = "GuardDuty finding severity threshold for immediate alerting. 7.0+ = High, 4.0-6.9 = Medium, 0.1-3.9 = Low."
  type        = number
  default     = 7.0
}

variable "security_alert_topic_arn" {
  description = "SNS topic ARN for high severity GuardDuty findings. From log-archive module or management-baseline module."
  type        = string
  default     = ""
}

variable "security_alert_email" {
  description = "Email for GuardDuty alerts if no SNS topic provided."
  type        = string
  default     = "emaina@arizona.edu"
}

# -----------------------------------------------------------
# SENTINEL INTEGRATION TOGGLE
# -----------------------------------------------------------
variable "enable_sentinel_integration" {
  description = "Route GuardDuty findings to Sentinel via Security Lake. Set false until Azure subscription is active."
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
    Phase           = "2-SecurityTooling"
    Module          = "guardduty"
  }
}