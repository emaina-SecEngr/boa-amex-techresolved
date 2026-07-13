# ============================================================
# variables.tf — Module input variables
# Module: detective
#
# WHAT THIS MODULE BUILDS:
# Amazon Detective behavior graph management.
# Detective builds a unified security graph connecting:
#   - CloudTrail events (API activity)
#   - VPC Flow Logs (network activity)
#   - GuardDuty findings (threat intelligence)
#
# EXISTING RESOURCE:
# Graph 97cadf0d24b147f0bfd76cfac41ea1a1 already running (this replaced
# the original fae265881c8e48fa81b6af5d7a2f62b4 graph — Detective allows
# only one graph per account/region, and that one no longer exists).
# Import before apply:
#   terraform import module.detective.aws_detective_graph.main \
#     arn:aws:detective:us-east-1:368351959735:graph:97cadf0d24b147f0bfd76cfac41ea1a1
#
# COST: ~$3/month (free trial expired July 31)
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
  description = "Security Tooling account ID."
  type        = string
  default     = "368351959735"
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

variable "existing_graph_arn" {
  description = "Existing Detective graph ARN. Import before apply."
  type        = string
  default     = "arn:aws:detective:us-east-1:368351959735:graph:97cadf0d24b147f0bfd76cfac41ea1a1"
}

variable "enable_detective" {
  description = "Enable Detective graph. Cannot be disabled via SCP — our DenyDisablingSecurity protects it."
  type        = bool
  default     = true
}

variable "member_accounts" {
  description = "Member account IDs to invite into the Detective graph."
  type        = list(string)
  default     = ["445459853572"]
}

variable "member_emails" {
  description = "Email addresses for member accounts. Must match account email."
  type        = map(string)
  default = {
    "445459853572" = "mwangi.maina83+audit@gmail.com"
  }
}

variable "enable_org_datasources" {
  description = "Enable organization-wide data sources for Detective."
  type        = bool
  default     = true
}

variable "security_alert_email" {
  description = "Email for Detective alerts."
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
    Module          = "detective"
  }
}