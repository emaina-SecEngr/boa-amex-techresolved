# ============================================================
# variables.tf — Module input variables
# Module: aws-organization
#
# WHAT THIS MODULE BUILDS:
# The complete AWS Organization structure — the governance
# foundation that everything else in this architecture
# depends on. This module must be deployed and verified
# before ANY other module is built.
#
# WHAT AWS ORGANIZATIONS PROVIDES:
# 1. Organizational Units (OUs) — folder structure grouping
#    accounts by purpose (Security, Production, Non-Prod)
# 2. Member accounts — separate AWS accounts per workload
# 3. Service Control Policies — guardrails that apply to
#    ALL accounts and cannot be overridden by anyone
# 4. Consolidated billing — one invoice for all accounts
# 5. Delegated administrator — Security Tooling manages
#    security services org-wide
#
# WHY THIS CANNOT BE SKIPPED:
# Without Organization + SCPs, any account administrator
# can disable GuardDuty, delete CloudTrail, or create
# public S3 buckets regardless of what policies exist.
# SCPs make those actions architecturally impossible —
# not just policy-prohibited. This is the difference
# OCC examiners specifically look for.
#
# ACCOUNT STRUCTURE:
#   Management (682391277575):    governance only, no workloads
#   Security Tooling (368351959735): all security infrastructure
#   PCI-CDE (TBD):                cardholder data workloads
#   Core Banking (TBD):           payment processing workloads
#   Dev (TBD):                    non-production environments
#   Pipeline/CI-CD (TBD):         Terraform, Checkov, SAST
#   Audit (TBD):                  OCC examiner read-only access
# ============================================================

variable "aws_region" {
  description = "Primary AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

# -----------------------------------------------------------
# ORGANIZATION IDENTITY
# -----------------------------------------------------------
variable "organization_id" {
  description = "Existing AWS Organization ID (o-xxxxxxxxxxx). Our org is o-tlzn7g9bvb. Passed as a variable so it can be referenced by other modules without hardcoding."
  type        = string
  default     = "o-tlzn7g9bvb"
}

variable "project_prefix" {
  description = "Short prefix applied to all named resources for identification. Format: company-project."
  type        = string
  default     = "boa-amex"
}

# -----------------------------------------------------------
# EXISTING ACCOUNT IDs
# These accounts already exist — we reference them,
# not create them. Terraform will manage their OU placement
# and policy attachments but not create or destroy them.
# -----------------------------------------------------------
variable "management_account_id" {
  description = "Management account ID — governance only, no workloads. Already exists."
  type        = string
  default     = "682391277575"
}

variable "security_tooling_account_id" {
  description = "Security Tooling account ID — all security infrastructure. Already exists."
  type        = string
  default     = "368351959735"
}

# -----------------------------------------------------------
# NEW ACCOUNT EMAILS
# Each new AWS account requires a globally unique email.
# Gmail+ aliases route to mwangi.maina83@gmail.com
# but AWS treats each as a unique address.
# -----------------------------------------------------------
variable "pci_cde_account_email" {
  description = "Email for PCI-CDE workload account. Must be globally unique across all AWS accounts."
  type        = string
  default     = "mwangi.maina83+pcicde@gmail.com"
}

variable "core_banking_account_email" {
  description = "Email for Core Banking workload account."
  type        = string
  default     = "mwangi.maina83+corebanking@gmail.com"
}

variable "dev_account_email" {
  description = "Email for Dev/Non-Production account."
  type        = string
  default     = "mwangi.maina83+dev@gmail.com"
}

variable "pipeline_account_email" {
  description = "Email for Pipeline/CI-CD account. Hosts Terraform Cloud, Checkov, SAST scanning."
  type        = string
  default     = "mwangi.maina83+pipeline@gmail.com"
}

variable "audit_account_email" {
  description = "Email for Audit account. Used exclusively by OCC examiners, internal audit, and PCI-DSS QSA auditors. Read-only access to all accounts."
  type        = string
  default     = "mwangi.maina83+audit@gmail.com"
}

# -----------------------------------------------------------
# ACCOUNT CREATION TOGGLES
# Creating AWS accounts via Terraform is irreversible
# without manual intervention — AWS makes account deletion
# extremely difficult by design. Each account creation
# must be explicitly enabled to prevent accidental creation.
# -----------------------------------------------------------
variable "create_pci_cde_account" {
  description = "Create the PCI-CDE workload account. WARNING: account creation via Terraform cannot be easily undone. Set true only when ready to create this account permanently."
  type        = bool
  default     = false
}

variable "create_core_banking_account" {
  description = "Create the Core Banking workload account. WARNING: see create_pci_cde_account warning."
  type        = bool
  default     = false
}

variable "create_dev_account" {
  description = "Create the Dev/Non-Production account."
  type        = bool
  default     = false
}

variable "create_pipeline_account" {
  description = "Create the Pipeline/CI-CD account."
  type        = bool
  default     = false
}

variable "create_audit_account" {
  description = "Create the Audit account for OCC examiner access. This should be one of the FIRST accounts created — OCC compliance requires it before workload accounts exist."
  type        = bool
  default     = false
}

# -----------------------------------------------------------
# OU STRUCTURE TOGGLES
# OUs are created in sequence — root first, then children.
# These toggles allow incremental buildout.
# -----------------------------------------------------------
variable "create_security_ou" {
  description = "Create Security OU containing Security Tooling and Log Archive accounts."
  type        = bool
  default     = true
}

variable "create_production_ou" {
  description = "Create Production OU containing PCI-CDE and Core Banking accounts."
  type        = bool
  default     = true
}

variable "create_non_production_ou" {
  description = "Create Non-Production OU containing Dev and QA accounts."
  type        = bool
  default     = true
}

variable "create_compliance_ou" {
  description = "Create Compliance OU containing Audit account."
  type        = bool
  default     = true
}

variable "create_pipeline_ou" {
  description = "Create Pipeline OU containing CI-CD accounts."
  type        = bool
  default     = true
}

# -----------------------------------------------------------
# DELEGATED ADMINISTRATOR CONFIGURATION
# Designates Security Tooling as the delegated admin
# for org-wide security services. Once delegated, Security
# Tooling can manage GuardDuty, Security Hub, and Detective
# across ALL accounts from a single pane of glass.
# -----------------------------------------------------------
variable "enable_guardduty_delegated_admin" {
  description = "Designate Security Tooling as GuardDuty delegated administrator. Enables org-wide GuardDuty management from Security Tooling account. Requires GuardDuty to be enabled in Security Tooling first."
  type        = bool
  default     = false
}

variable "enable_securityhub_delegated_admin" {
  description = "Designate Security Tooling as Security Hub delegated administrator. Enables unified findings aggregation across all accounts."
  type        = bool
  default     = false
}

variable "enable_detective_delegated_admin" {
  description = "Designate Security Tooling as Detective delegated administrator. Enables org-wide behavior graph."
  type        = bool
  default     = false
}

variable "enable_config_delegated_admin" {
  description = "Designate Security Tooling as AWS Config delegated administrator. Enables centralized Config aggregation across all accounts."
  type        = bool
  default     = false
}

variable "enable_macie_delegated_admin" {
  description = "Designate Security Tooling as Macie delegated administrator. Enables org-wide sensitive-data discovery findings, relevant for locating cardholder data outside the PCI-CDE account."
  type        = bool
  default     = false
}

variable "enable_backup_delegated_admin" {
  description = "Designate Security Tooling as AWS Backup delegated administrator. Enables centralized backup policy management and monitoring across all accounts."
  type        = bool
  default     = false
}

# -----------------------------------------------------------
# ORG-WIDE SERVICE ENABLEMENT
# These enable AWS services at the Organization level —
# meaning they automatically apply to every account,
# including new accounts created in the future.
# -----------------------------------------------------------
variable "enable_aws_service_access" {
  description = "List of AWS service principals to enable org-wide. Each service enabled here can use Organizations features (delegated admin, org-wide data sharing) across all accounts."
  type        = list(string)
  default = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "detective.amazonaws.com",
    "access-analyzer.amazonaws.com",
    "macie.amazonaws.com",
    "sso.amazonaws.com",
    "ram.amazonaws.com",
    "tagpolicies.tag.amazonaws.com",
    "backup.amazonaws.com"
  ]
}

variable "common_tags" {
  description = "Tags applied to all taggable resources in this module."
  type        = map(string)
  default = {
    Project         = "BOA-AMEX-TechResolved"
    Owner           = "Eliud-Maina"
    Consultant      = "Abuhari-Consulting-Services"
    ManagedBy       = "Terraform"
    ComplianceScope = "PCI-DSS-v4 OCC-12CFR30 NIST-800-53"
    Phase           = "1-Foundation"
  }
}