# ============================================================
# variables.tf — Module input variables
# Module: iam-identity-center
#
# WHAT THIS MODULE BUILDS:
# Complete AWS IAM Identity Center configuration with
# Microsoft Entra ID as the external Identity Provider.
#
# THREE COMPONENTS:
# 1. External IdP Connection (Entra ID via SAML 2.0)
#    One login from Entra ID works across ALL AWS accounts
#    SCIM provisioning auto-syncs users/groups from Entra ID
#
# 2. Permission Sets — what each role can do in AWS
#    SecurityAuditor: read-only across all accounts
#    Developer: limited access in Dev/NonProd only
#    NetworkAdmin: network resources only
#    BreakGlass: full admin, time-limited, alarmed
#    OCCExaminer: read-only across all accounts for auditors
#
# 3. Service Control Policies (SCPs)
#    Applied at OU level — cannot be overridden by anyone
#    DenyRootUsage, DenyPublicS3, DenyRegionExit,
#    RequireEncryption, DenyDisablingSecurityServices
#
# ENTRA ID INTEGRATION FLAG:
# deploy_entra_id_connection = false  → everything built
#                                       except SAML IdP link
# deploy_entra_id_connection = true   → full Entra ID SSO
#                                       ONE variable flip
#
# WHAT YOU NEED FROM ENTRA ID (when subscription ready):
#   entra_saml_metadata_url  — from Enterprise App in Azure
#   entra_scim_endpoint      — from Identity Center SCIM setup
#   entra_scim_token         — from Identity Center SCIM setup
#   entra_tenant_id          — your Azure tenant ID
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
  description = "Management account ID."
  type        = string
  default     = "682391277575"
}

variable "security_tooling_account_id" {
  description = "Security Tooling account ID."
  type        = string
  default     = "368351959735"
}

variable "audit_account_id" {
  description = "Audit account ID for OCC examiner access."
  type        = string
  default     = "445459853572"
}

# -----------------------------------------------------------
# ORGANIZATION STRUCTURE
# OU IDs needed for SCP attachment
# These come from aws-organization module outputs
# -----------------------------------------------------------
variable "root_id" {
  description = "Organization root ID (r-iaiz) — SCPs attached here apply to ALL accounts."
  type        = string
  default     = "r-iaiz"
}

variable "security_ou_id" {
  description = "Security OU ID — strictest SCPs applied here."
  type        = string
  default     = ""
}

variable "production_ou_id" {
  description = "Production OU ID — strict SCPs, no console access."
  type        = string
  default     = ""
}

variable "non_production_ou_id" {
  description = "Non-Production OU ID — relaxed SCPs for developer access."
  type        = string
  default     = ""
}

variable "compliance_ou_id" {
  description = "Compliance OU ID — DenyAllWrites SCP applied here."
  type        = string
  default     = ""
}

variable "pipeline_ou_id" {
  description = "Pipeline OU ID — assume-role only SCP applied here."
  type        = string
  default     = ""
}

# -----------------------------------------------------------
# MASTER DEPLOYMENT TOGGLES
# -----------------------------------------------------------
variable "deploy_identity_center" {
  description = "Deploy Identity Center Permission Sets and assignments. Set true once Identity Center is enabled in the Management account."
  type        = bool
  default     = true
}

variable "deploy_scps" {
  description = "Deploy Service Control Policies to OUs. Set true when OU IDs are known. SCPs are the most critical security control — deploy as early as possible."
  type        = bool
  default     = true
}

# -----------------------------------------------------------
# ENTRA ID CONNECTION TOGGLE
# The single flag that connects everything to Entra ID
# Everything else deploys with this set to false
# Flip to true when Azure subscription is available
# -----------------------------------------------------------
variable "deploy_entra_id_connection" {
  description = "Connect Identity Center to Microsoft Entra ID via SAML 2.0. Set false to build all Permission Sets and SCPs without IdP connection. Flip to true when Entra ID subscription is available. Requires entra_* variables to be populated."
  type        = bool
  default     = false
}

# -----------------------------------------------------------
# ENTRA ID CONFIGURATION
# Populated when deploy_entra_id_connection = true
# Leave as empty strings until Azure subscription ready
# -----------------------------------------------------------
variable "entra_tenant_id" {
  description = "Microsoft Entra ID tenant ID (GUID format). Found in Azure Portal → Entra ID → Overview → Tenant ID. Required when deploy_entra_id_connection = true."
  type        = string
  default     = ""
  sensitive   = true
}

variable "entra_idp_sign_in_url" {
  description = "Entra ID SAML sign-in URL (IdP SSO URL). Format: https://login.microsoftonline.com/{tenant-id}/saml2. Required when deploy_entra_id_connection = true."
  type        = string
  default     = ""
}

variable "entra_idp_issuer_url" {
  description = "Entra ID SAML issuer URL. Format: https://sts.windows.net/{tenant-id}/. Required when deploy_entra_id_connection = true."
  type        = string
  default     = ""
}

# -----------------------------------------------------------
# PERMISSION SET SESSION DURATIONS
# How long each role's session lasts before re-auth required
# Shorter = more secure, more friction
# Longer = less friction, slightly less secure
# -----------------------------------------------------------
variable "security_auditor_session_hours" {
  description = "SecurityAuditor session duration. Read-only role — 8 hours (full work day)."
  type        = number
  default     = 8
}

variable "developer_session_hours" {
  description = "Developer session duration. 4 hours — re-authenticate mid-day for security."
  type        = number
  default     = 4
}

variable "network_admin_session_hours" {
  description = "NetworkAdmin session duration. 4 hours — network changes are high-risk."
  type        = number
  default     = 4
}

variable "break_glass_session_hours" {
  description = "BreakGlass session duration. 1 hour maximum — emergency only, alarmed, reviewed. Short duration limits blast radius if credentials are compromised during emergency."
  type        = number
  default     = 1
}

variable "occ_examiner_session_hours" {
  description = "OCCExaminer session duration. 8 hours — full examination day. Time-limited assignment, not permanent access."
  type        = number
  default     = 8
}

# -----------------------------------------------------------
# BREAK GLASS CONFIGURATION
# Break Glass = emergency admin access when normal access fails
# Must be monitored, time-limited, and reviewed after use
# -----------------------------------------------------------
variable "break_glass_alert_email" {
  description = "Email address that receives IMMEDIATE alert when Break Glass is used. Should go to CISO and Security team simultaneously."
  type        = string
  default     = "emaina@arizona.edu"
}

variable "break_glass_sns_topic_arn" {
  description = "SNS topic ARN for Break Glass alerts. If empty, module creates its own SNS topic. Pass existing topic ARN to consolidate alerts."
  type        = string
  default     = ""
}

# -----------------------------------------------------------
# APPROVED REGIONS
# Restricts which AWS regions can be used org-wide
# via DenyRegionExit SCP
# Only regions listed here are allowed for resource creation
# -----------------------------------------------------------
variable "approved_regions" {
  description = "List of approved AWS regions. The DenyRegionExit SCP blocks resource creation in any region not in this list. Add regions only when workloads require them."
  type        = list(string)
  default     = ["us-east-1", "us-west-2"]
}

variable "common_tags" {
  description = "Tags applied to all taggable resources."
  type        = map(string)
  default = {
    Project         = "BOA-AMEX-TechResolved"
    Owner           = "Eliud-Maina"
    Consultant      = "Abuhari-Consulting-Services"
    ManagedBy       = "Terraform"
    ComplianceScope = "PCI-DSS-v4 OCC-12CFR30 NIST-800-53"
    Phase           = "1-Foundation"
    Module          = "iam-identity-center"
  }
}