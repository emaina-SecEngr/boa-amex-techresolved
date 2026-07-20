# ============================================================
# variables.tf — Module input variables
# Module: audit-account
#
# WHAT THIS MODULE BUILDS:
# Cross-account IAM read-only roles in every AWS account
# that trust the Audit account (445459853572).
#
# WHY THIS IS NEEDED:
# The Audit account is where OCC examiners log in via
# the OCCExaminer Permission Set. From there, they need
# to LOOK INTO other accounts (Security Tooling, Management,
# etc.) without having direct credentials in each account.
#
# Cross-account roles enable this:
#   Examiner logs into Audit account (445459853572)
#   Assumes AuditReadOnly role in Security Tooling
#   Gets read-only view of Security Tooling resources
#   Cannot modify anything (DenyAllWrites SCP + read-only policy)
#
# WHAT GETS CREATED PER ACCOUNT:
#   aws_iam_role.audit_readonly
#     Trust: arn:aws:iam::445459853572:root
#     Policy: SecurityAudit + ViewOnlyAccess
#   aws_iam_role_policy_attachment × 2
#
# DEPLOYMENT:
#   This module deploys into EACH target account
#   using provider aliases (one per account)
#   The Management environment wires all providers together
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

variable "audit_account_id" {
  description = "Audit account ID (445459853572). Cross-account roles trust this account."
  type        = string
  default     = "445459853572"
}

variable "management_account_id" {
  description = "Management account ID."
  type        = string
  default     = "682391277575"
}

variable "security_tooling_account_id" {
  description = "Security Tooling account ID."
  type        = string
  default     = "368351959735"
}

# -----------------------------------------------------------
# WORKLOAD ACCOUNT IDs
# Passed in from module.aws_organization outputs. Empty string
# means the account doesn't exist yet (e.g. customer_portal,
# which hit the AWS Organizations account limit) — the
# corresponding create_*_audit_role toggle must stay false
# until a real account id is available.
# -----------------------------------------------------------
variable "pci_cde_account_id" {
  description = "PCI-CDE workload account ID."
  type        = string
  default     = ""
}

variable "core_banking_account_id" {
  description = "Core Banking workload account ID."
  type        = string
  default     = ""
}

variable "dev_account_id" {
  description = "Dev workload account ID."
  type        = string
  default     = ""
}

variable "pipeline_account_id" {
  description = "Pipeline/CI-CD workload account ID."
  type        = string
  default     = ""
}

variable "fraud_detection_account_id" {
  description = "Fraud Detection workload account ID."
  type        = string
  default     = ""
}

variable "customer_portal_account_id" {
  description = "Customer Portal workload account ID. Empty until the account is actually created."
  type        = string
  default     = ""
}

variable "data_analytics_account_id" {
  description = "Data Analytics workload account ID."
  type        = string
  default     = ""
}

variable "bi_reporting_account_id" {
  description = "BI Reporting workload account ID."
  type        = string
  default     = ""
}

# -----------------------------------------------------------
# ROLE CONFIGURATION
# -----------------------------------------------------------
variable "audit_role_name" {
  description = "Name of the cross-account read-only role created in each account. OCC examiners assume this role from the Audit account."
  type        = string
  default     = "AuditReadOnly"
}

variable "audit_role_description" {
  description = "Description for the cross-account audit role."
  type        = string
  default     = "Read-only role for OCC examiners and internal auditors. Assumed from Audit account (445459853572). Cannot modify any resource."
}

variable "max_session_duration" {
  description = "Maximum session duration in seconds for the audit role. 8 hours = 28800 seconds (full examination day)."
  type        = number
  default     = 28800
}

# -----------------------------------------------------------
# ACCOUNT TOGGLES
# Enable cross-account role creation per account
# -----------------------------------------------------------
variable "create_management_audit_role" {
  description = "Create audit read-only role in Management account."
  type        = bool
  default     = true
}

variable "create_security_tooling_audit_role" {
  description = "Create audit read-only role in Security Tooling account."
  type        = bool
  default     = true
}

variable "create_pci_cde_audit_role" {
  description = "Create audit read-only role in PCI-CDE account."
  type        = bool
  default     = true
}

variable "create_core_banking_audit_role" {
  description = "Create audit read-only role in Core Banking account."
  type        = bool
  default     = true
}

variable "create_dev_audit_role" {
  description = "Create audit read-only role in Dev account."
  type        = bool
  default     = true
}

variable "create_pipeline_audit_role" {
  description = "Create audit read-only role in Pipeline/CI-CD account."
  type        = bool
  default     = true
}

variable "create_fraud_detection_audit_role" {
  description = "Create audit read-only role in Fraud Detection account."
  type        = bool
  default     = true
}

variable "create_customer_portal_audit_role" {
  description = "Create audit read-only role in Customer Portal account. Must stay false until the account actually exists (currently blocked by the AWS Organizations account limit)."
  type        = bool
  default     = false
}

variable "create_data_analytics_audit_role" {
  description = "Create audit read-only role in Data Analytics account."
  type        = bool
  default     = true
}

variable "create_bi_reporting_audit_role" {
  description = "Create audit read-only role in BI Reporting account."
  type        = bool
  default     = true
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
    Module          = "audit-account"
  }
}
