# ============================================================
# main.tf — Amazon Security Lake OCSF normalization layer
# Module: security-lake
#
# DEPLOYMENT ACCOUNT: Security Tooling (368351959735)
# PREREQUISITE: log-archive, guardduty, security-hub complete
# ============================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  # Every log source below ingests from this set of accounts.
  # Security Lake has no org-wide auto-enable resource, so new
  # accounts must be added to member_accounts and re-applied.
  log_source_accounts = var.enable_org_sources ? concat([local.account_id], var.member_accounts) : [local.account_id]
}

# -----------------------------------------------------------
# SERVICE LINKED ROLE
# Security Lake needs a service linked role to access
# S3, KMS, and other AWS services on your behalf
# -----------------------------------------------------------
resource "aws_iam_service_linked_role" "security_lake" {
  aws_service_name = "securitylake.amazonaws.com"
  description      = "Service linked role for Amazon Security Lake"
}

# -----------------------------------------------------------
# SECURITY LAKE — core data lake
# Creates the OCSF-formatted S3 data lake
# -----------------------------------------------------------
resource "aws_securitylake_data_lake" "main" {
  count = var.enable_security_lake ? 1 : 0

  meta_store_manager_role_arn = aws_iam_role.security_lake_meta.arn

  configuration {
    region = local.region

    encryption_configuration {
      kms_key_id = var.log_archive_kms_key_arn != "" ? var.log_archive_kms_key_arn : null
    }

    lifecycle_configuration {
      transition {
        days          = var.security_lake_transition_days
        storage_class = "ONEZONE_IA"
      }
      expiration {
        days = var.security_lake_retention_days
      }
    }
  }

  depends_on = [
    aws_iam_service_linked_role.security_lake,
    aws_iam_role_policy_attachment.security_lake_meta
  ]

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-security-lake"
    Purpose = "OCSF normalized security data lake — Sentinel ingestion source"
  })
}

# -----------------------------------------------------------
# META STORE MANAGER ROLE
# Security Lake uses this role to manage the Glue
# data catalog (metadata for querying OCSF data)
# -----------------------------------------------------------
resource "aws_iam_role" "security_lake_meta" {
  name = "${var.project_prefix}-security-lake-meta-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-security-lake-meta-role"
    Purpose = "Security Lake meta store manager"
  })
}

resource "aws_iam_role_policy_attachment" "security_lake_meta" {
  role       = aws_iam_role.security_lake_meta.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSecurityLakeMetastoreManager"
}

# -----------------------------------------------------------
# LOG SOURCES
# Each source automatically normalizes logs to OCSF
# -----------------------------------------------------------

# CloudTrail — API activity in OCSF format
resource "aws_securitylake_aws_log_source" "cloudtrail" {
  count = var.enable_security_lake && var.enable_cloudtrail_source ? 1 : 0

  source {
    accounts    = local.log_source_accounts
    regions     = [local.region]
    source_name = "CLOUD_TRAIL_MGMT"
  }

  depends_on = [aws_securitylake_data_lake.main]
}

# VPC Flow Logs — network activity in OCSF format
resource "aws_securitylake_aws_log_source" "vpc_flow_logs" {
  count = var.enable_security_lake && var.enable_vpc_flow_logs_source ? 1 : 0

  source {
    accounts    = local.log_source_accounts
    regions     = [local.region]
    source_name = "VPC_FLOW"
  }

  depends_on = [aws_securitylake_data_lake.main]
}

# Security Hub findings — compliance findings in OCSF
resource "aws_securitylake_aws_log_source" "security_hub" {
  count = var.enable_security_lake && var.enable_security_hub_source ? 1 : 0

  source {
    accounts    = local.log_source_accounts
    regions     = [local.region]
    source_name = "SH_FINDINGS"
  }

  depends_on = [aws_securitylake_data_lake.main]
}

# Route 53 resolver — DNS activity in OCSF format
resource "aws_securitylake_aws_log_source" "route53" {
  count = var.enable_security_lake && var.enable_route53_source ? 1 : 0

  source {
    accounts    = local.log_source_accounts
    regions     = [local.region]
    source_name = "ROUTE53"
  }

  depends_on = [aws_securitylake_data_lake.main]
}

# Lambda execution logs — serverless activity in OCSF format
resource "aws_securitylake_aws_log_source" "lambda" {
  count = var.enable_security_lake && var.enable_lambda_source ? 1 : 0

  source {
    accounts    = local.log_source_accounts
    regions     = [local.region]
    source_name = "LAMBDA_EXECUTION"
  }

  depends_on = [aws_securitylake_data_lake.main]
}

# -----------------------------------------------------------
# SENTINEL SUBSCRIBER
# Creates an IAM role that Sentinel assumes to read
# OCSF data from Security Lake S3 bucket
# Toggled off until Azure subscription is restored
# -----------------------------------------------------------
resource "aws_securitylake_subscriber" "sentinel" {
  count                  = var.enable_security_lake && var.enable_sentinel_integration ? 1 : 0
  subscriber_name        = "${var.project_prefix}-sentinel-subscriber"
  subscriber_description = "Microsoft Sentinel subscriber — reads OCSF normalized findings for SIEM ingestion"

  access_type = "S3"

  source {
    aws_log_source_resource {
      source_name    = "CLOUD_TRAIL_MGMT"
      source_version = "2.0"
    }
  }

  source {
    aws_log_source_resource {
      source_name    = "VPC_FLOW"
      source_version = "2.0"
    }
  }

  source {
    aws_log_source_resource {
      source_name    = "SH_FINDINGS"
      source_version = "2.0"
    }
  }

  subscriber_identity {
    external_id = var.sentinel_external_id != "" ? var.sentinel_external_id : "BOA-AMEX-SENTINEL"
    principal   = "arn:aws:iam::197857026523:root"
  }

  depends_on = [
    aws_securitylake_data_lake.main,
    aws_securitylake_aws_log_source.cloudtrail,
    aws_securitylake_aws_log_source.vpc_flow_logs,
    aws_securitylake_aws_log_source.security_hub
  ]

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-sentinel-subscriber"
    Purpose = "Microsoft Sentinel SIEM integration via Security Lake"
  })
}

# -----------------------------------------------------------
# SQS QUEUE FOR SENTINEL NOTIFICATIONS
# Sentinel polls this queue to know when new data
# is available in Security Lake S3 bucket
# Toggled with Sentinel integration
# -----------------------------------------------------------
resource "aws_securitylake_subscriber_notification" "sentinel" {
  count         = var.enable_security_lake && var.enable_sentinel_integration ? 1 : 0
  subscriber_id = aws_securitylake_subscriber.sentinel[0].id

  configuration {
    sqs_notification_configuration {}
  }

  depends_on = [aws_securitylake_subscriber.sentinel]
}

# -----------------------------------------------------------
# ALERTING
# SNS topic backing the CloudWatch alarm below
# -----------------------------------------------------------
resource "aws_sns_topic" "security_lake_alerts" {
  name = "${var.project_prefix}-security-lake-alerts"

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-security-lake-alerts"
    Purpose = "Security Lake ingestion spike alerts"
  })
}

resource "aws_sns_topic_subscription" "security_lake_alert_email" {
  topic_arn = aws_sns_topic.security_lake_alerts.arn
  protocol  = "email"
  endpoint  = var.security_alert_email
}

# -----------------------------------------------------------
# CLOUDWATCH ALARM — Security Lake ingestion monitoring
# Monitors data ingestion volume
# Spike indicates active attack or high activity period
# -----------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "security_lake_ingestion" {
  alarm_name          = "${var.project_prefix}-security-lake-ingestion-spike"
  alarm_description   = "Security Lake ingestion volume spike — possible active attack generating high log volume"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "TotalStorageSize"
  namespace           = "AWS/SecurityLake"
  period              = 3600
  statistic           = "Sum"
  threshold           = 5368709120
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.security_lake_alerts.arn]

  tags = merge(var.common_tags, {
    Name     = "${var.project_prefix}-security-lake-ingestion-spike"
    Severity = "MEDIUM"
  })
}