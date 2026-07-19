# ============================================================
# variables.tf — Module input variables
# Module: crowdstrike
#
# WHAT THIS MODULE BUILDS:
# CrowdStrike Falcon integration infrastructure:
#
# 1. Falcon Sensor deployment via SSM
#    Automatically installs Falcon agent on ALL EC2
#    instances using SSM Distributor + Association
#    New instances auto-enrolled on launch
#
# 2. Falcon Horizon cross-account role (CSPM)
#    IAM role that CrowdStrike assumes for cloud
#    configuration scanning (CSPM/CIEM)
#    Same pattern as WizScanner role
#
# 3. FDR S3 bucket (Falcon Data Replicator)
#    CrowdStrike streams all telemetry here
#    Lambda processes → OCSF → Security Lake → Sentinel
#
# 4. Lambda FDR processor
#    Normalizes CrowdStrike JSON to OCSF format
#    Routes to Security Lake for Sentinel ingestion
#
# TOGGLE: enable_crowdstrike = false by default
# Enable when CrowdStrike trial/subscription active
#
# TRIAL: Contact CrowdStrike for 15-day free trial
# crowdstrike.com/free-trial
#
# PRODUCTION COST:
#   Falcon Go:       ~$5.99/endpoint/month
#   Falcon Pro:      ~$8.99/endpoint/month
#   Falcon Enterprise: ~$15.99/endpoint/month
#   Falcon Elite:    ~$18.99/endpoint/month
#   Our sandbox (0 EC2 now): $0
#   Phase 5 (LBB + workloads): ~$50-100/month
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

variable "log_archive_kms_key_arn" {
  description = "KMS key ARN for FDR bucket encryption."
  type        = string
  default     = ""
}

# -----------------------------------------------------------
# MASTER TOGGLE
# -----------------------------------------------------------
variable "enable_crowdstrike" {
  description = "Enable CrowdStrike integration. Set true when trial/subscription is active and CID is available."
  type        = bool
  default     = false
}

# -----------------------------------------------------------
# CROWDSTRIKE ACCOUNT CONFIGURATION
# Values provided by CrowdStrike during onboarding
# -----------------------------------------------------------
variable "crowdstrike_cid" {
  description = "CrowdStrike Customer ID (CID). Found in Falcon console → Host Setup → Sensor Downloads → CID. Required for sensor installation."
  type        = string
  default     = ""
  sensitive   = true
}

variable "crowdstrike_aws_account_id" {
  description = "CrowdStrike AWS account ID for Falcon Horizon cross-account role. Provided during Horizon connector setup."
  type        = string
  default     = "292230061137"
}

variable "crowdstrike_external_id" {
  description = "External ID for Falcon Horizon IAM role trust policy. Provided during Horizon connector setup."
  type        = string
  default     = ""
  sensitive   = true
}

# -----------------------------------------------------------
# FALCON SENSOR DEPLOYMENT
# -----------------------------------------------------------
variable "enable_sensor_deployment" {
  description = "Deploy Falcon sensor to all EC2 instances via SSM Distributor. Requires SSM Agent on instances and CrowdStrike CID."
  type        = bool
  default     = true
}

variable "sensor_version" {
  description = "Falcon sensor version to deploy. Use 'Latest' for always current. Pin version for controlled rollouts."
  type        = string
  default     = "Latest"
}

variable "sensor_target_platform" {
  description = "Target platform for sensor deployment."
  type        = string
  default     = "Linux"

  validation {
    condition     = contains(["Linux", "Windows", "Both"], var.sensor_target_platform)
    error_message = "Must be Linux, Windows, or Both."
  }
}

variable "ssm_association_schedule" {
  description = "Schedule for SSM Association to check/install sensor. Cron expression. Default: daily at 2 AM."
  type        = string
  default     = "cron(0 2 * * ? *)"
}

# -----------------------------------------------------------
# FALCON HORIZON (CSPM)
# -----------------------------------------------------------
variable "enable_falcon_horizon" {
  description = "Enable Falcon Horizon cross-account CSPM scanning."
  type        = bool
  default     = true
}

# -----------------------------------------------------------
# FALCON DATA REPLICATOR (FDR)
# Streams all Falcon telemetry to S3 for Sentinel ingestion
# -----------------------------------------------------------
variable "enable_fdr" {
  description = "Enable Falcon Data Replicator — streams all detections to S3 for Security Lake → Sentinel ingestion."
  type        = bool
  default     = true
}

variable "fdr_bucket_name" {
  description = "S3 bucket name for Falcon Data Replicator telemetry."
  type        = string
  default     = "boa-amex-crowdstrike-fdr-368351959735"
}

variable "fdr_retention_days" {
  description = "Days to retain FDR data in S3 before transitioning to Glacier."
  type        = number
  default     = 90
}

# -----------------------------------------------------------
# DETECTION MODULES
# -----------------------------------------------------------
variable "enable_edr" {
  description = "Enable EDR (Endpoint Detection and Response) — records all endpoint activity for investigation."
  type        = bool
  default     = true
}

variable "enable_identity_protection" {
  description = "Enable Falcon Identity Protection — monitors AD/Entra ID for credential attacks."
  type        = bool
  default     = true
}

variable "enable_container_security" {
  description = "Enable Falcon Container Security — protects ECS/EKS workloads."
  type        = bool
  default     = false
}

# -----------------------------------------------------------
# ALERTING
# -----------------------------------------------------------
variable "critical_detection_threshold" {
  description = "CrowdStrike detection severity for immediate alert. 1=informational, 2=low, 3=medium, 4=high, 5=critical."
  type        = number
  default     = 4
}

variable "security_alert_email" {
  description = "Email for critical CrowdStrike detections."
  type        = string
  default     = "emaina@arizona.edu"
}

variable "security_alert_topic_arn" {
  description = "Existing SNS topic ARN for alerts. If empty creates new topic."
  type        = string
  default     = ""
}

# -----------------------------------------------------------
# SENTINEL INTEGRATION
# -----------------------------------------------------------
variable "enable_sentinel_integration" {
  description = "Route CrowdStrike FDR data to Sentinel via Security Lake. Set false until Azure subscription active."
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
    Phase      = "3-ExtendedDetection"
    Module     = "crowdstrike"
  }
}