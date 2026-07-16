# ============================================================
# variables.tf — Module input variables
# Module: soar
#
# WHAT THIS MODULE BUILDS:
# 27 automated security response playbooks organized
# into 4 categories:
#
# INFRASTRUCTURE (5 playbooks):
#   ec2-isolate, ip-block, s3-remediate,
#   secret-rotate, snapshot-forensics
#
# IAM (7 playbooks):
#   iam-key-disable, iam-policy-rollback,
#   iam-user-quarantine, iam-role-boundary,
#   iam-root-lockdown, iam-session-revoke,
#   iam-cross-account
#
# TOKEN (7 playbooks):
#   token-sts-revoke, token-imds-lockdown,
#   token-key-exposed, token-jwt-validation,
#   token-refresh-revoke, token-secrets-abuse,
#   token-imdsv1-enforce
#
# CONTAINER/EKS (8 playbooks):
#   eks-pod-quarantine, eks-container-escape,
#   eks-service-account, eks-cryptominer-kill,
#   eks-image-violation, eks-rbac-escalation,
#   eks-secret-exposure, eks-namespace-breach
#
# ARCHITECTURE:
#   EventBridge rules → match finding type
#   → Step Functions → orchestrate response
#   → Lambda playbooks → execute actions
#   → SNS → notify security team
#   → CloudTrail → audit trail of response
#
# COST: ~$0 (Lambda free tier covers sandbox usage)
#   Lambda: first 1M requests/month free
#   Step Functions: first 4,000 state transitions/month free
#   EventBridge: first 1M events/month free
#   SNS: first 1M notifications/month free
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
# MASTER TOGGLES — enable/disable playbook categories
# -----------------------------------------------------------
variable "enable_soar" {
  description = "Master toggle for all SOAR playbooks. Set false to disable all automated responses."
  type        = bool
  default     = true
}

variable "enable_infrastructure_playbooks" {
  description = "Enable infrastructure response playbooks (EC2 isolate, IP block, S3 remediate, secret rotate, snapshot forensics)."
  type        = bool
  default     = true
}

variable "enable_iam_playbooks" {
  description = "Enable IAM response playbooks (key disable, policy rollback, user quarantine, role boundary, root lockdown, session revoke, cross-account audit)."
  type        = bool
  default     = true
}

variable "enable_token_playbooks" {
  description = "Enable token response playbooks (STS revoke, IMDS lockdown, key exposed, JWT validation, refresh revoke, secrets abuse, IMDSv1 enforce)."
  type        = bool
  default     = true
}

variable "enable_container_playbooks" {
  description = "Enable container/EKS response playbooks (pod quarantine, container escape, service account, cryptominer, image violation, RBAC escalation, secret exposure, namespace breach)."
  type        = bool
  default     = false
}
variable "enable_network_playbooks" {
  description = "Enable network response playbooks (DDoS response, port scan block, DNS hijack revert, lateral movement containment)."
  type        = bool
  default     = true
}

variable "enable_runtime_playbooks" {
  description = "Enable runtime response playbooks (reverse shell kill, privilege escalation containment, webshell removal, fileless malware response)."
  type        = bool
  default     = true
}

variable "enable_vulnerability_playbooks" {
  description = "Enable vulnerability response playbooks (critical CVE emergency patching, supply chain compromise response)."
  type        = bool
  default     = true
}

variable "enable_data_exfiltration_playbooks" {
  description = "Enable data exfiltration response playbooks (S3 theft, DNS tunneling, RDS data theft). Critical for PCI-DSS breach response."
  type        = bool
  default     = true
}

# -----------------------------------------------------------
# RESPONSE MODE — auto vs approval
# Production: require approval for destructive actions
# Sandbox: auto-respond for testing
# -----------------------------------------------------------
variable "response_mode" {
  description = "SOAR response mode. AUTO = respond immediately without human approval. APPROVAL = create incident and wait for human approval before executing. AUTO recommended for sandbox, APPROVAL for production."
  type        = string
  default     = "AUTO"

  validation {
    condition     = contains(["AUTO", "APPROVAL"], var.response_mode)
    error_message = "Must be AUTO or APPROVAL."
  }
}

variable "approval_timeout_minutes" {
  description = "Minutes to wait for human approval before auto-executing in APPROVAL mode. After timeout the playbook executes automatically to limit blast radius."
  type        = number
  default     = 15
}

# -----------------------------------------------------------
# QUARANTINE CONFIGURATION
# -----------------------------------------------------------
variable "quarantine_vpc_id" {
  description = "VPC ID where quarantine Security Group is created. Compromised EC2 instances are moved to this SG which denies all traffic."
  type        = string
  default     = ""
}

variable "quarantine_sg_name" {
  description = "Name of the quarantine Security Group. Denies all ingress and egress — completely isolates the instance."
  type        = string
  default     = "soar-quarantine-deny-all"
}

# -----------------------------------------------------------
# FORENSICS CONFIGURATION
# -----------------------------------------------------------
variable "forensics_bucket_name" {
  description = "S3 bucket for forensic evidence (EBS snapshots, memory dumps, pod logs). Separate from log archive for chain of custody."
  type        = string
  default     = ""
}

variable "evidence_retention_days" {
  description = "Days to retain forensic evidence. Legal hold may require indefinite. Default 2555 = 7 years (OCC requirement)."
  type        = number
  default     = 2555
}

# -----------------------------------------------------------
# BLOCKED IP LIST
# -----------------------------------------------------------
variable "ip_blocklist_prefix_list_id" {
  description = "AWS Prefix List ID for blocked IPs. SOAR playbooks add malicious IPs here. Referenced by Security Groups and Network Firewall."
  type        = string
  default     = ""
}

# -----------------------------------------------------------
# EKS CONFIGURATION
# Required for container playbooks
# -----------------------------------------------------------
variable "eks_cluster_name" {
  description = "EKS cluster name for container playbooks. Required when enable_container_playbooks = true."
  type        = string
  default     = ""
}

variable "eks_cluster_arn" {
  description = "EKS cluster ARN."
  type        = string
  default     = ""
}

# -----------------------------------------------------------
# REFERENCES FROM OTHER MODULES
# -----------------------------------------------------------
variable "log_archive_bucket_name" {
  description = "Log archive S3 bucket name."
  type        = string
  default     = "boa-amex-log-archive-368351959735"
}

variable "log_archive_kms_key_arn" {
  description = "KMS key ARN for log encryption."
  type        = string
  default     = ""
}

variable "guardduty_detector_id" {
  description = "GuardDuty detector ID for finding context."
  type        = string
  default     = "b6cf6963ce4553017b19d5bb98e6b209"
}

variable "security_hub_arn" {
  description = "Security Hub ARN for finding updates."
  type        = string
  default     = ""
}

# -----------------------------------------------------------
# ALERTING
# -----------------------------------------------------------
variable "security_alert_email" {
  description = "Email for SOAR execution notifications."
  type        = string
  default     = "emaina@arizona.edu"
}

variable "critical_alert_email" {
  description = "Email for CRITICAL SOAR events (container escape, root lockdown). May be different from standard alerts — goes to CISO."
  type        = string
  default     = "emaina@arizona.edu"
}

variable "existing_alert_topic_arn" {
  description = "Existing SNS topic ARN for alerts. If empty creates new topic."
  type        = string
  default     = ""
}

# -----------------------------------------------------------
# SENTINEL INTEGRATION
# -----------------------------------------------------------
variable "enable_sentinel_integration" {
  description = "Send SOAR execution logs to Sentinel. Every playbook action logged and correlated with the triggering finding."
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default = {
    Project    = "BOA-AMEX-TechResolved"
    Owner      = "Eliud-Maina"
    Consultant = "Abuhari-Consulting-Services"
    ManagedBy  = "Terraform"
    Phase      = "4-SOAR"
    Module     = "soar"
  }
}