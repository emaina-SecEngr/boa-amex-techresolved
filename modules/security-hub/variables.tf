# ============================================================
# variables.tf — Module input variables
# Module: security-hub
#
# WHAT THIS MODULE BUILDS:
# Organization-wide Security Hub configuration with Security
# Tooling as the aggregator. Security Hub provides:
#
# 1. COMPLIANCE STANDARDS — automated checks against:
#    - CIS AWS Foundations Benchmark (135 controls)
#    - PCI-DSS v3.2.1 (requirements 1-12)
#    - AWS Foundational Security Best Practices (200+ controls)
#
# 2. FINDING AGGREGATION — collects findings from:
#    - GuardDuty (threat detection)
#    - Config (compliance monitoring)
#    - IAM Access Analyzer (access analysis)
#    - Inspector (vulnerability scanning)
#    - Macie (data classification)
#    - Wiz (CSPM — Phase 2 Module 6)
#
# 3. CROSS-ACCOUNT VISIBILITY — one console shows
#    findings from ALL accounts in the Organization
#
# WHY AFTER GUARDDUTY:
#    Security Hub ingests GuardDuty findings
#    GuardDuty must exist before Security Hub
#    can aggregate its findings
#
# SENTINEL INTEGRATION:
#    Security Hub findings → EventBridge → Lambda
#    → Security Lake → Sentinel
#    Toggle: enable_sentinel_integration = false
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
  description = "Security Tooling account ID — Security Hub aggregator."
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
# SECURITY HUB CONFIGURATION
# -----------------------------------------------------------
variable "enable_security_hub" {
  description = "Enable Security Hub in Security Tooling account."
  type        = bool
  default     = true
}

variable "auto_enable_controls" {
  description = "Automatically enable new controls when standards are updated. Keeps compliance posture current without manual intervention."
  type        = bool
  default     = true
}

variable "control_finding_generator" {
  description = "How Security Hub generates findings. SECURITY_CONTROL generates one finding per control across all standards. STANDARD_CONTROL generates separate findings per standard."
  type        = string
  default     = "SECURITY_CONTROL"
}

# -----------------------------------------------------------
# COMPLIANCE STANDARDS
# Each standard has a cost per check per account
# All enabled by default — defense in depth
# -----------------------------------------------------------
variable "enable_cis_standard" {
  description = "Enable CIS AWS Foundations Benchmark. 135 controls covering IAM, logging, networking, monitoring. Required for OCC examination readiness."
  type        = bool
  default     = true
}

variable "enable_pci_dss_standard" {
  description = "Enable PCI-DSS v3.2.1 standard. Maps PCI requirements to AWS controls. Required for card payment processing compliance."
  type        = bool
  default     = true
}

variable "enable_aws_foundational_standard" {
  description = "Enable AWS Foundational Security Best Practices. 200+ controls across all AWS services. Broadest coverage."
  type        = bool
  default     = true
}

variable "enable_nist_standard" {
  description = "Enable NIST SP 800-53 Rev 5 standard. Federal security controls mapped to AWS. Aligns with OCC 12 CFR Part 30."
  type        = bool
  default     = false
}

# -----------------------------------------------------------
# FINDING AGGREGATION
# Cross-account finding aggregation pulls findings
# from all member accounts into Security Tooling
# -----------------------------------------------------------
variable "enable_finding_aggregation" {
  description = "Enable cross-account finding aggregation. Pulls Security Hub findings from all member accounts into Security Tooling for unified visibility."
  type        = bool
  default     = true
}

# -----------------------------------------------------------
# ORG-WIDE CONFIGURATION
# -----------------------------------------------------------
variable "enable_org_auto_enable" {
  description = "Automatically enable Security Hub in all new accounts added to the Organization."
  type        = bool
  default     = true
}

# -----------------------------------------------------------
# ALERTING
# -----------------------------------------------------------
variable "critical_finding_threshold" {
  description = "Security Hub finding severity for immediate alert. CRITICAL = active threat, HIGH = significant risk."
  type        = string
  default     = "CRITICAL"

  validation {
    condition     = contains(["CRITICAL", "HIGH", "MEDIUM", "LOW"], var.critical_finding_threshold)
    error_message = "Must be CRITICAL, HIGH, MEDIUM, or LOW."
  }
}

variable "security_alert_email" {
  description = "Email for critical Security Hub findings."
  type        = string
  default     = "emaina@arizona.edu"
}

# -----------------------------------------------------------
# SENTINEL INTEGRATION TOGGLE
# -----------------------------------------------------------
variable "enable_sentinel_integration" {
  description = "Route Security Hub findings to Sentinel via Security Lake. Set false until Azure subscription is active. NOTE: no export pipeline exists in this module yet (unlike guardduty's aws_guardduty_publishing_destination) — flipping this to true has no effect until that pipeline is built."
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
    Module          = "security-hub"
  }
}