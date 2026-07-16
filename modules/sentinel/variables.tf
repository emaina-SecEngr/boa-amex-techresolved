# ============================================================
# variables.tf — Module input variables
# Module: sentinel
#
# WHAT THIS MODULE BUILDS:
# Microsoft Sentinel SIEM connector infrastructure on the
# AWS side. This module creates the resources AWS needs to
# SEND data to Sentinel — not Sentinel itself (that's Azure).
#
# THREE COMPONENTS:
# 1. SQS queues — Sentinel polls these for new data
#    One queue per data source (CloudTrail, GuardDuty, etc.)
#
# 2. IAM role — Sentinel assumes this to read S3 data
#    Cross-account trust to Microsoft's Azure account
#
# 3. S3 notifications — trigger SQS when new logs arrive
#    Sentinel polls SQS → reads S3 → ingests logs
#
# TOGGLE: enable_sentinel = false
# Enable when Azure student subscription is restored
# Requires: Sentinel workspace ID and primary key
#
# DATA FLOW WHEN ENABLED:
#   AWS security logs → S3 buckets (already flowing)
#   S3 new object → SQS notification
#   Sentinel polls SQS → reads S3 → ingests to workspace
#   Analytics rules fire → incidents created
#   SOAR playbooks respond automatically
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
# MASTER TOGGLE
# -----------------------------------------------------------
variable "enable_sentinel" {
  description = "Enable Sentinel SIEM connector. Set true when Azure subscription is active and Sentinel workspace exists. Requires sentinel_workspace_id and sentinel_role_arn."
  type        = bool
  default     = false
}

# -----------------------------------------------------------
# SENTINEL WORKSPACE CONFIGURATION
# Values from Azure Portal → Sentinel → Settings
# -----------------------------------------------------------
variable "sentinel_workspace_id" {
  description = "Microsoft Sentinel Log Analytics workspace ID. Found in Azure Portal → Sentinel → Settings → Workspace settings → Workspace ID."
  type        = string
  default     = ""
  sensitive   = true
}

variable "sentinel_workspace_key" {
  description = "Microsoft Sentinel Log Analytics primary key. Found in Azure Portal → Log Analytics → Agents → Primary key."
  type        = string
  default     = ""
  sensitive   = true
}

variable "sentinel_azure_tenant_id" {
  description = "Azure tenant ID for Sentinel workspace."
  type        = string
  default     = "288a15d1-700c-482b-a591-7c1d4e6c4f3c"
}

variable "sentinel_role_arn" {
  description = "IAM role ARN that Sentinel assumes to read AWS data. Created by this module. The ARN is pasted into Sentinel AWS S3 connector configuration."
  type        = string
  default     = ""
}

# -----------------------------------------------------------
# DATA SOURCES — which AWS logs flow to Sentinel
# Each creates an SQS queue and S3 notification
# -----------------------------------------------------------
variable "enable_cloudtrail_connector" {
  description = "Send CloudTrail logs to Sentinel. Provides complete API activity visibility."
  type        = bool
  default     = true
}

variable "enable_guardduty_connector" {
  description = "Send GuardDuty findings to Sentinel. Provides threat detection visibility."
  type        = bool
  default     = true
}

variable "enable_security_hub_connector" {
  description = "Send Security Hub findings to Sentinel. Provides compliance visibility."
  type        = bool
  default     = true
}

variable "enable_vpc_flow_logs_connector" {
  description = "Send VPC Flow Logs to Sentinel. Provides network traffic visibility."
  type        = bool
  default     = true
}

variable "enable_waf_connector" {
  description = "Send WAF logs to Sentinel. Provides web application attack visibility."
  type        = bool
  default     = false
}

# -----------------------------------------------------------
# S3 BUCKET REFERENCES
# Where each data source stores logs
# -----------------------------------------------------------
variable "log_archive_bucket_name" {
  description = "Log archive S3 bucket name containing CloudTrail and security logs."
  type        = string
  default     = "boa-amex-log-archive-368351959735"
}

variable "log_archive_bucket_arn" {
  description = "Log archive S3 bucket ARN."
  type        = string
  default     = ""
}

variable "log_archive_kms_key_arn" {
  description = "KMS key ARN for decrypting log archive data."
  type        = string
  default     = ""
}

# -----------------------------------------------------------
# ALERTING
# -----------------------------------------------------------
variable "security_alert_email" {
  description = "Email for Sentinel connector health alerts."
  type        = string
  default     = "emaina@arizona.edu"
}

variable "common_tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default = {
    Project    = "BOA-AMEX-TechResolved"
    Owner      = "Eliud-Maina"
    Consultant = "Abuhari-Consulting-Services"
    ManagedBy  = "Terraform"
    Phase      = "3-ExtendedDetection"
    Module     = "sentinel"
  }
}