# ============================================================
# variables.tf — Module input variables
# Module: wiz
#
# WHAT THIS MODULE BUILDS:
# Cross-account IAM roles that allow Wiz CNAPP platform
# to perform agentless scanning of AWS accounts.
#
# HOW WIZ SCANNING WORKS (agentless):
# 1. Wiz assumes the WizScanner IAM role in your account
# 2. Creates EBS snapshots of running volumes
# 3. Mounts snapshots in Wiz's own AWS account
# 4. Scans for vulnerabilities, malware, secrets
# 5. Analyzes IAM policies for CIEM findings
# 6. Maps network exposure for CSPM findings
# 7. Deletes snapshots when done
# 8. Reports findings to Wiz console + Security Lake
#
# NO AGENT INSTALLED — zero performance impact on workloads
# NO DATA LEAVES AWS — Wiz works within AWS regions
#
# WHAT WIZ DETECTS:
# CSPM: cloud misconfigurations
#   "S3 bucket publicly accessible"
#   "Security group open to 0.0.0.0/0"
#   "KMS key rotation disabled"
#
# CWPP: workload vulnerabilities
#   "EC2 running kernel with CVE-2023-1234"
#   "Container image has 47 critical CVEs"
#   "Lambda using deprecated runtime"
#
# CIEM: identity risks
#   "IAM role has AdministratorAccess, never used"
#   "Service account can delete all S3 buckets"
#   "Cross-account trust too permissive"
#
# Security Graph: attack path analysis
#   "Internet → EC2 (CVE) → IAM Role → S3 (PII)"
#   Shows complete blast radius of each finding
#
# TRIAL:
# Wiz offers 30-day free trial
# Contact: sales@wiz.io or wiz.io/free-trial
# Provide your AWS account IDs for connector setup
# Wiz gives you their AWS account ID for trust policy
#
# PRODUCTION COST: $500K-2M+/year enterprise contract
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

# -----------------------------------------------------------
# WIZ CONNECTOR CONFIGURATION
# Values provided by Wiz during trial/onboarding
# -----------------------------------------------------------
variable "wiz_tenant_id" {
  description = "Wiz tenant ID — provided during Wiz onboarding. Format: UUID. Found in Wiz console → Settings → Tenant."
  type        = string
  default     = ""
  sensitive   = true
}

variable "wiz_aws_account_id" {
  description = "Wiz's AWS account ID that assumes your WizScanner role. Provided during Wiz connector setup. Different per Wiz region (US/EU)."
  type        = string
  default     = "197857026523"
}

variable "wiz_external_id" {
  description = "External ID for WizScanner role trust policy. Prevents confused deputy attacks. Provided during Wiz connector setup."
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_wiz_scanner" {
  description = "Create WizScanner IAM role. Set true when Wiz trial is active and wiz_aws_account_id + wiz_external_id are provided."
  type        = bool
  default     = true
}

# -----------------------------------------------------------
# SCANNING PERMISSIONS
# Controls what Wiz can scan in your accounts
# -----------------------------------------------------------
variable "enable_cspm_scanning" {
  description = "Enable CSPM scanning — Wiz reads resource configurations to detect misconfigurations. Read-only, no performance impact."
  type        = bool
  default     = true
}

variable "enable_cwpp_scanning" {
  description = "Enable CWPP scanning — Wiz creates EBS snapshots to scan for vulnerabilities and malware. Snapshots deleted after scan."
  type        = bool
  default     = true
}

variable "enable_ciem_scanning" {
  description = "Enable CIEM scanning — Wiz analyzes IAM policies and permissions for excessive access and toxic combinations."
  type        = bool
  default     = true
}

variable "enable_data_scanning" {
  description = "Enable data scanning — Wiz scans S3 objects for PII, PAN, secrets. Required for PCI-DSS data classification evidence."
  type        = bool
  default     = true
}

variable "enable_kubernetes_scanning" {
  description = "Enable Kubernetes scanning — Wiz scans EKS clusters for misconfigurations and vulnerabilities."
  type        = bool
  default     = false
}

# -----------------------------------------------------------
# KMS KEY GRANTS
# Allow Wiz to decrypt EBS snapshots for vulnerability scanning
# Without this Wiz cannot scan encrypted volumes
# -----------------------------------------------------------
variable "enable_kms_grants" {
  description = "Grant Wiz permission to decrypt KMS-encrypted EBS snapshots. Required for CWPP scanning of encrypted volumes."
  type        = bool
  default     = true
}

variable "log_archive_kms_key_arn" {
  description = "KMS key ARN from log-archive module. Grant Wiz decrypt access for scanning."
  type        = string
  default     = ""
}

# -----------------------------------------------------------
# FINDINGS INTEGRATION
# Route Wiz findings to Security Lake → Sentinel
# -----------------------------------------------------------
variable "enable_findings_integration" {
  description = "Enable Wiz findings export to Security Lake. Requires Wiz webhook configuration in Wiz console."
  type        = bool
  default     = false
}

variable "findings_webhook_secret" {
  description = "Webhook secret for Wiz findings export. Generated in Wiz console → Integrations → AWS Security Lake."
  type        = string
  default     = ""
  sensitive   = true
}

variable "security_alert_email" {
  description = "Email for critical Wiz findings."
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
    Module          = "wiz"
  }
}