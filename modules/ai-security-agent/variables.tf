# ============================================================
# variables.tf — Module input variables
# Module: ai-security-agent
#
# WHAT THIS MODULE BUILDS:
# A Bedrock-backed Lambda that triages GuardDuty/Security Hub
# findings into natural-language summaries and — when
# authorized — invokes the existing SOAR dispatcher
# (modules/soar) to run a response playbook. Deploys into
# Security Tooling (368351959735), alongside GuardDuty,
# Security Hub, and SOAR.
#
# ACTION AUTHORITY:
# enable_autonomous_response=true wires the IAM permission and
# code path that let this agent invoke SOAR playbooks on its
# own judgment — but allowed_playbooks defaults to an empty
# list, so nothing is actually authorized until you populate
# it. Triage/summarization runs regardless of that list.
# ============================================================

variable "aws_region" {
  description = "Primary AWS region."
  type        = string
  default     = "us-east-1"
}

variable "project_prefix" {
  description = "Short prefix for resource naming."
  type        = string
}

variable "security_tooling_account_id" {
  description = "Security Tooling account ID — this module deploys here."
  type        = string
}

variable "management_account_id" {
  description = "Management account ID."
  type        = string
}

variable "organization_id" {
  description = "AWS Organization ID."
  type        = string
}

variable "audit_account_id" {
  description = "Audit account ID."
  type        = string
}

variable "common_tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------
# MASTER TOGGLE
# -----------------------------------------------------------
variable "enable_ai_security_agent" {
  description = "Deploy the AI Security Agent (Lambda + EventBridge rules + SNS topic)."
  type        = bool
  default     = false
}

# -----------------------------------------------------------
# BEDROCK CONFIGURATION
# -----------------------------------------------------------
variable "bedrock_model_id" {
  description = "Bedrock model ID used for triage. Model access must be requested/approved in the AWS Console for this account before InvokeModel calls succeed — Terraform cannot automate that step."
  type        = string
  default     = "anthropic.claude-sonnet-4-5-20250929-v1:0"
}

variable "bedrock_region" {
  description = "Region to call Bedrock in. Defaults to aws_region — override if the chosen model is only available via a cross-region inference profile in a different region."
  type        = string
  default     = ""
}

# -----------------------------------------------------------
# TRIAGE SCOPE
# -----------------------------------------------------------
variable "triage_severity_threshold" {
  description = "Minimum GuardDuty severity (0-10 scale) that triggers agent triage. Lower than the 7.0 threshold used for human paging elsewhere, since this agent's job is broad triage coverage, not just critical alerting."
  type        = number
  default     = 4.0
}

# -----------------------------------------------------------
# ACTION AUTHORITY
# -----------------------------------------------------------
variable "enable_autonomous_response" {
  description = "Grant the agent's Lambda role lambda:InvokeFunction on the SOAR dispatcher and enable the code path that calls it. Even when true, the agent only ever invokes playbooks listed in allowed_playbooks."
  type        = bool
  default     = true
}

variable "allowed_playbooks" {
  description = "SOAR playbook names (from soar_playbook_catalog) the agent is authorized to invoke autonomously. Defaults to an empty list — the agent still triages and publishes every decision to SNS, but the invoke-SOAR step no-ops until this is populated. Scoping which of the 40 playbooks (some far higher blast-radius than others) is a deliberate, separate decision from turning autonomy on."
  type        = list(string)
  default     = []
}

variable "soar_dispatcher_arn" {
  description = "ARN of the SOAR dispatcher Lambda (module.soar.soar_dispatcher_arn). The agent invokes this directly with the same {playbook, source, finding_type, severity, account_id, resource_arn, finding_id} payload shape SOAR's own EventBridge rules use."
  type        = string
  default     = ""
}

variable "soar_playbook_catalog" {
  description = "Full list of valid SOAR playbook names. modules/soar exposes its catalog only as a human-readable text block (outputs.tf playbook_catalog), not a structured list, so this is maintained here and must be kept in sync with that module. Used to validate the model's recommended_playbook before ever considering an invoke."
  type        = list(string)
  default = [
    "ec2-isolate", "ip-block", "s3-remediate", "secret-rotate", "snapshot-forensics",
    "iam-key-disable", "iam-policy-rollback", "iam-user-quarantine", "iam-role-boundary",
    "iam-root-lockdown", "iam-session-revoke", "iam-cross-account",
    "token-sts-revoke", "token-imds-lockdown", "token-key-exposed", "token-jwt-validation",
    "token-refresh-revoke", "token-secrets-abuse", "token-imdsv1-enforce",
    "eks-pod-quarantine", "eks-container-escape", "eks-service-account", "eks-cryptominer-kill",
    "eks-image-violation", "eks-rbac-escalation", "eks-secret-exposure", "eks-namespace-breach",
    "network-ddos-response", "network-port-scan-block", "network-dns-hijack", "network-lateral-movement",
    "runtime-reverse-shell", "runtime-priv-escalation", "runtime-webshell-detect", "runtime-fileless-malware",
    "vulnerability-critical-cve", "vulnerability-supply-chain",
    "data-exfil-s3", "data-exfil-dns", "data-exfil-rds"
  ]
}

variable "security_alert_email" {
  description = "Email subscribed to the agent's SNS alert topic — every triage decision and playbook invocation, successful or not."
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for the agent Lambda."
  type        = number
  default     = 90
}
