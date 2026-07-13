# ============================================================
# variables.tf — Module input variables
# Module: config
#
# WHAT THIS MODULE BUILDS:
# AWS Config configuration recorder + delivery channel for a
# single account/region. This is the data source that backs:
#   - Security Hub compliance standards (CIS, PCI-DSS, NIST,
#     AWS Foundational) — those standards have no data to
#     evaluate without a running recorder
#   - The org-wide Config aggregator already created in
#     modules/management-baseline (aws_config_configuration_aggregator)
#
# WHY THIS MODULE IS SEPARATE FROM management-baseline:
# The aggregator in management-baseline only PULLS data — it
# needs a aws_config_aggregate_authorization grant in each
# source account, plus an actual recorder running in each
# account. Config has no org-wide "auto-enable" toggle the way
# GuardDuty/Security Hub do; the recorder is provisioned
# per-account, per-region. Deploy this module once per account
# (Security Tooling first, then Audit, then workload accounts).
#
# COST CONTROL — READ BEFORE CHANGING recorded_resource_types:
# AWS Config bills per configuration item recorded ($0.003,
# continuous mode) plus per rule evaluation. Recording
# all_supported resource types records every change to every
# resource type in the account, including high-churn types
# (Lambda versions, ECS tasks, CloudFormation stacks) that can
# turn a small account into a large bill. This module defaults
# to INCLUSION_BY_RESOURCE_TYPES — an explicit allow-list of the
# resource types that actually matter for CIS/PCI-DSS/NIST
# evidence — instead of all_supported = true.
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
  description = "Management account ID — holds the org-wide Config aggregator (modules/management-baseline)."
  type        = string
  default     = "682391277575"
}

variable "organization_id" {
  description = "AWS Organization ID."
  type        = string
  default     = "o-tlzn7g9bvb"
}

# -----------------------------------------------------------
# RECORDER CONFIGURATION
# -----------------------------------------------------------
variable "enable_config" {
  description = "Enable the Config recorder in this account. Required for Security Hub's CIS/PCI-DSS/NIST/AWS-Foundational standards to produce findings."
  type        = bool
  default     = true
}

variable "recording_frequency" {
  description = "CONTINUOUS records every resource change as it happens. DAILY records once per 24h per resource type — cheaper but delays compliance detection. Use CONTINUOUS for resource types tied to PCI/CIS controls."
  type        = string
  default     = "CONTINUOUS"

  validation {
    condition     = contains(["CONTINUOUS", "DAILY"], var.recording_frequency)
    error_message = "Must be CONTINUOUS or DAILY."
  }
}

variable "recorded_resource_types" {
  description = "Explicit allow-list of resource types to record (recording_strategy = INCLUSION_BY_RESOURCE_TYPES). Cost control — avoids recording every supported resource type in the account. IAM types are global; only enable them in ONE recorder region per account."
  type        = list(string)
  default = [
    # Identity & access (global — see include_global_resource_types note in main.tf)
    "AWS::IAM::Role",
    "AWS::IAM::Policy",
    "AWS::IAM::User",
    "AWS::IAM::Group",

    # Network
    "AWS::EC2::SecurityGroup",
    "AWS::EC2::VPC",
    "AWS::EC2::Subnet",
    "AWS::EC2::NetworkAcl",
    "AWS::EC2::InternetGateway",
    "AWS::EC2::EIP",
    "AWS::ElasticLoadBalancingV2::LoadBalancer",

    # Compute
    "AWS::EC2::Instance",
    "AWS::EC2::Volume",
    "AWS::Lambda::Function",
    "AWS::ECS::Cluster",
    "AWS::EKS::Cluster",

    # Data & storage
    "AWS::S3::Bucket",
    "AWS::RDS::DBInstance",
    "AWS::RDS::DBSecurityGroup",
    "AWS::DynamoDB::Table",

    # Encryption & secrets
    "AWS::KMS::Key",
    "AWS::SecretsManager::Secret",

    # Logging & edge security
    "AWS::CloudTrail::Trail",
    "AWS::WAFv2::WebACL",
  ]
}

# NOTE: there is no include_global_resource_types variable here.
# That flag only applies when all_supported = true. This module
# uses INCLUSION_BY_RESOURCE_TYPES, so IAM (a global resource
# type) is recorded only because "AWS::IAM::Role" etc. are
# listed explicitly in recorded_resource_types above — AWS Config
# records listed global types regardless of any other flag. Only
# list the IAM types in ONE recorder/region per account, or you
# get duplicate global-resource configuration items and double
# billing for them.

# -----------------------------------------------------------
# DELIVERY CHANNEL
# Delivers configuration snapshots + history to the existing
# Log Archive bucket (already grants config.amazonaws.com
# write access — see modules/log-archive/main.tf)
# -----------------------------------------------------------
variable "log_archive_bucket_name" {
  description = "Log archive bucket for Config snapshots/history. From log-archive module output."
  type        = string
  default     = "boa-amex-log-archive-368351959735"
}

variable "log_archive_kms_key_arn" {
  description = "KMS key ARN for encrypting delivered Config snapshots. From log-archive module output."
  type        = string
  default     = ""
}

variable "s3_key_prefix" {
  description = "Prefix within the log archive bucket for Config delivery."
  type        = string
  default     = "config"
}

variable "snapshot_delivery_frequency" {
  description = "How often Config delivers a full configuration snapshot to S3. Snapshot delivery is billed as S3 PUTs, not configuration items — TwentyFour_Hours is the cost-conscious default."
  type        = string
  default     = "TwentyFour_Hours"
}

# -----------------------------------------------------------
# CROSS-ACCOUNT AGGREGATION
# Authorizes the org-wide aggregator (management-baseline
# module, deployed in Management account) to pull this
# account's Config data.
# -----------------------------------------------------------
variable "enable_aggregator_authorization" {
  description = "Grant the Management account's org-wide Config aggregator permission to read this account's Config data."
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
    Phase           = "2-SecurityTooling"
    Module          = "config"
  }
}
