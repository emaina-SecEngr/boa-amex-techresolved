# ============================================================
# main.tf — Microsoft Sentinel SIEM connector (AWS side)
# Module: sentinel
#
# DEPLOYMENT ACCOUNT: Security Tooling (368351959735)
# TOGGLE: enable_sentinel = false until Azure is fixed
#
# This module builds the AWS-side plumbing:
#   SQS queues that Sentinel polls
#   IAM role that Sentinel assumes
#   S3 event notifications that trigger SQS
#
# The Azure-side (Sentinel workspace, analytics rules,
# SOAR playbooks) is configured in Azure Portal after
# these AWS resources exist.
# ============================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

# -----------------------------------------------------------
# IAM ROLE FOR SENTINEL
# Sentinel assumes this role to read S3 data and poll SQS
# Trust policy allows Microsoft's collector service
# -----------------------------------------------------------
resource "aws_iam_role" "sentinel_reader" {
  count = var.enable_sentinel ? 1 : 0
  name  = "${var.project_prefix}-sentinel-reader"

  description = "Cross-account role for Microsoft Sentinel. Sentinel assumes this role to read security logs from S3 and poll SQS queues."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSentinelAssume"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::197857026523:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.sentinel_workspace_id
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-sentinel-reader"
    Purpose = "Microsoft Sentinel SIEM cross-account data reader"
  })
}

# S3 read permissions for Sentinel
resource "aws_iam_role_policy" "sentinel_s3_read" {
  count = var.enable_sentinel ? 1 : 0
  name  = "${var.project_prefix}-sentinel-s3-read"
  role  = aws_iam_role.sentinel_reader[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadLogArchive"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::${var.log_archive_bucket_name}",
          "arn:aws:s3:::${var.log_archive_bucket_name}/*"
        ]
      },
      {
        Sid    = "DecryptLogs"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = var.log_archive_kms_key_arn != "" ? [var.log_archive_kms_key_arn] : ["*"]
      },
      {
        Sid    = "PollSQSQueues"
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = "arn:aws:sqs:${local.region}:${local.account_id}:${var.project_prefix}-sentinel-*"
      }
    ]
  })
}

# -----------------------------------------------------------
# SQS QUEUES — one per data source
# S3 sends notification → SQS → Sentinel polls SQS
# Sentinel reads the S3 object referenced in the message
# -----------------------------------------------------------

# CloudTrail queue
resource "aws_sqs_queue" "sentinel_cloudtrail" {
  count = var.enable_sentinel && var.enable_cloudtrail_connector ? 1 : 0
  name  = "${var.project_prefix}-sentinel-cloudtrail"

  visibility_timeout_seconds = 300
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 20

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3Notification"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = "arn:aws:sqs:${local.region}:${local.account_id}:${var.project_prefix}-sentinel-cloudtrail"
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:s3:::${var.log_archive_bucket_name}"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name       = "${var.project_prefix}-sentinel-cloudtrail"
    DataSource = "CloudTrail"
    Purpose    = "Sentinel polls this queue for new CloudTrail logs"
  })
}

# GuardDuty queue
resource "aws_sqs_queue" "sentinel_guardduty" {
  count = var.enable_sentinel && var.enable_guardduty_connector ? 1 : 0
  name  = "${var.project_prefix}-sentinel-guardduty"

  visibility_timeout_seconds = 300
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 20

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3Notification"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = "arn:aws:sqs:${local.region}:${local.account_id}:${var.project_prefix}-sentinel-guardduty"
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:s3:::${var.log_archive_bucket_name}"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name       = "${var.project_prefix}-sentinel-guardduty"
    DataSource = "GuardDuty"
    Purpose    = "Sentinel polls this queue for new GuardDuty findings"
  })
}

# Security Hub queue
resource "aws_sqs_queue" "sentinel_security_hub" {
  count = var.enable_sentinel && var.enable_security_hub_connector ? 1 : 0
  name  = "${var.project_prefix}-sentinel-security-hub"

  visibility_timeout_seconds = 300
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 20

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3Notification"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = "arn:aws:sqs:${local.region}:${local.account_id}:${var.project_prefix}-sentinel-security-hub"
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:s3:::${var.log_archive_bucket_name}"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name       = "${var.project_prefix}-sentinel-security-hub"
    DataSource = "SecurityHub"
    Purpose    = "Sentinel polls this queue for new Security Hub findings"
  })
}

# VPC Flow Logs queue
resource "aws_sqs_queue" "sentinel_vpc_flow_logs" {
  count = var.enable_sentinel && var.enable_vpc_flow_logs_connector ? 1 : 0
  name  = "${var.project_prefix}-sentinel-vpc-flow-logs"

  visibility_timeout_seconds = 300
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 20

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3Notification"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = "arn:aws:sqs:${local.region}:${local.account_id}:${var.project_prefix}-sentinel-vpc-flow-logs"
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:s3:::${var.log_archive_bucket_name}"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name       = "${var.project_prefix}-sentinel-vpc-flow-logs"
    DataSource = "VPCFlowLogs"
    Purpose    = "Sentinel polls this queue for new VPC Flow Log data"
  })
}

# -----------------------------------------------------------
# DEAD LETTER QUEUES
# Messages that fail processing go here
# Monitored for connector health
# -----------------------------------------------------------
resource "aws_sqs_queue" "sentinel_dlq" {
  count = var.enable_sentinel ? 1 : 0
  name  = "${var.project_prefix}-sentinel-dlq"

  message_retention_seconds = 1209600

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-sentinel-dlq"
    Purpose = "Dead letter queue for failed Sentinel messages"
  })
}

# -----------------------------------------------------------
# CONNECTOR HEALTH ALARM
# Fires when messages pile up in DLQ
# Indicates Sentinel is not reading data
# -----------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "sentinel_dlq_depth" {
  count               = var.enable_sentinel ? 1 : 0
  alarm_name          = "${var.project_prefix}-sentinel-dlq-depth"
  alarm_description   = "Sentinel dead letter queue has messages - connector may be broken. Check Azure Sentinel data connector status."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.sentinel_dlq[0].name
  }

  tags = merge(var.common_tags, {
    Name     = "${var.project_prefix}-sentinel-dlq-depth"
    Severity = "HIGH"
  })
}

# -----------------------------------------------------------
# SNS TOPIC FOR CONNECTOR HEALTH
# -----------------------------------------------------------
resource "aws_sns_topic" "sentinel_health" {
  count = var.enable_sentinel ? 1 : 0
  name  = "${var.project_prefix}-sentinel-health"

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-sentinel-health"
    Purpose = "Microsoft Sentinel connector health alerts"
  })
}

resource "aws_sns_topic_subscription" "sentinel_health_email" {
  count     = var.enable_sentinel ? 1 : 0
  topic_arn = aws_sns_topic.sentinel_health[0].arn
  protocol  = "email"
  endpoint  = var.security_alert_email
}