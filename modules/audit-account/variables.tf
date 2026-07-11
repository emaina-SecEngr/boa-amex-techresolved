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
