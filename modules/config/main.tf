# ============================================================
# main.tf — AWS Config recorder + delivery channel
# Module: config
#
# DEPLOYMENT ACCOUNT: Security Tooling (368351959735) first,
# then replicate this module per additional account (Audit,
# workload accounts) — Config has no org-wide auto-enable.
# PREREQUISITE: log-archive module complete (bucket policy
# already grants config.amazonaws.com write access)
# ============================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

# -----------------------------------------------------------
# IAM ROLE — lets the Config recorder read resource configs
# -----------------------------------------------------------
resource "aws_iam_role" "config" {
  name = "${var.project_prefix}-config-recorder-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-config-recorder-role"
    Purpose = "AWS Config configuration recorder execution role"
  })
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

# Recorder needs write access to the log archive bucket/KMS key
# beyond what the AWS_ConfigRole managed policy covers for
# cross-account delivery.
resource "aws_iam_role_policy" "config_delivery" {
  name = "${var.project_prefix}-config-delivery"
  role = aws_iam_role.config.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3Delivery"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetBucketAcl"
        ]
        Resource = [
          "arn:aws:s3:::${var.log_archive_bucket_name}",
          "arn:aws:s3:::${var.log_archive_bucket_name}/${var.s3_key_prefix}/*"
        ]
      },
      {
        Sid    = "AllowKMSEncrypt"
        Effect = "Allow"
        Action = [
          "kms:GenerateDataKey*",
          "kms:Decrypt"
        ]
        Resource = var.log_archive_kms_key_arn
      }
    ]
  })
}

# -----------------------------------------------------------
# CONFIGURATION RECORDER
# INCLUSION_BY_RESOURCE_TYPES — records only the resource
# types listed in var.recorded_resource_types instead of every
# supported type. This is the primary cost control: recording
# all_supported types bills a configuration item for every
# change to every resource of every type, including high-churn
# types (Lambda versions, ECS tasks) that don't matter for
# CIS/PCI-DSS/NIST evidence.
# -----------------------------------------------------------
resource "aws_config_configuration_recorder" "main" {
  name     = "${var.project_prefix}-config-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported  = false
    resource_types = var.recorded_resource_types

    recording_strategy {
      use_only = "INCLUSION_BY_RESOURCE_TYPES"
    }
  }

  recording_mode {
    recording_frequency = var.recording_frequency
  }
}

# -----------------------------------------------------------
# DELIVERY CHANNEL
# Ships snapshots + configuration history to the Log Archive
# bucket. snapshot_delivery_properties controls how often a
# FULL snapshot is written (billed as S3 PUTs) — this is
# separate from configuration item recording above.
# -----------------------------------------------------------
resource "aws_config_delivery_channel" "main" {
  name           = "${var.project_prefix}-config-delivery-channel"
  s3_bucket_name = var.log_archive_bucket_name
  s3_key_prefix  = var.s3_key_prefix
  s3_kms_key_arn = var.log_archive_kms_key_arn

  snapshot_delivery_properties {
    delivery_frequency = var.snapshot_delivery_frequency
  }

  depends_on = [aws_config_configuration_recorder.main]
}

# Config requires the delivery channel to exist before the
# recorder can be started.
resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = var.enable_config

  depends_on = [aws_config_delivery_channel.main]
}

# -----------------------------------------------------------
# CROSS-ACCOUNT AGGREGATION
# Authorizes the org-wide Config aggregator (created in
# modules/management-baseline, deployed in the Management
# account) to pull this account's Config data. Without this,
# the aggregator has nothing to aggregate from this account.
# -----------------------------------------------------------
resource "aws_config_aggregate_authorization" "management" {
  count      = var.enable_aggregator_authorization ? 1 : 0
  account_id = var.management_account_id
  region     = local.region

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-config-aggregator-authorization"
    Purpose = "Allows Management account's org-wide Config aggregator to read this account"
  })
}
