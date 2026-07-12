# ============================================================
# main.tf — Organization-wide GuardDuty configuration
# Module: guardduty
#
# DEPLOYMENT ACCOUNT: Security Tooling (368351959735)
# PREREQUISITE: log-archive module complete
# IMPORT REQUIRED:
#   terraform import module.guardduty.aws_guardduty_detector.main \
#     b6cf6963ce4553017b19d5bb98e6b209
# ============================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

# -----------------------------------------------------------
# GUARDDUTY DETECTOR
# The core detector that analyzes all log sources
# IMPORTED from existing detector — not created fresh
# -----------------------------------------------------------
resource "aws_guardduty_detector" "main" {
  enable = var.enable_guardduty

  finding_publishing_frequency = var.finding_publishing_frequency

  # S3 Protection — monitors data access patterns
  datasources {
    s3_logs {
      enable = var.enable_s3_protection
    }
    kubernetes {
      audit_logs {
        enable = var.enable_eks_protection
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = var.enable_malware_protection
        }
      }
    }
  }

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-guardduty-detector"
    Purpose = "ML-based threat detection across all Organization accounts"
  })
}

# -----------------------------------------------------------
# PROTECTION PLANS — additional coverage beyond core detector
# -----------------------------------------------------------
resource "aws_guardduty_detector_feature" "rds_login_events" {
  count       = var.enable_rds_protection ? 1 : 0
  detector_id = aws_guardduty_detector.main.id
  name        = "RDS_LOGIN_EVENTS"
  status      = "ENABLED"
}

resource "aws_guardduty_detector_feature" "lambda_network_logs" {
  count       = var.enable_lambda_protection ? 1 : 0
  detector_id = aws_guardduty_detector.main.id
  name        = "LAMBDA_NETWORK_LOGS"
  status      = "ENABLED"
}

resource "aws_guardduty_detector_feature" "runtime_monitoring" {
  count       = var.enable_runtime_monitoring ? 1 : 0
  detector_id = aws_guardduty_detector.main.id
  name        = "RUNTIME_MONITORING"
  status      = "ENABLED"
}

# -----------------------------------------------------------
# FINDINGS EXPORT TO S3
# Exports all findings to Log Archive bucket
# Required for Security Lake ingestion → Sentinel
# -----------------------------------------------------------

# Create the guardduty prefix in the log archive bucket
resource "aws_s3_object" "guardduty_prefix" {
  count                  = var.enable_findings_export ? 1 : 0
  bucket                 = var.log_archive_bucket_name
  key                    = "guardduty/"
  content                = ""
  server_side_encryption = "aws:kms"
  kms_key_id             = var.log_archive_kms_key_arn
}

resource "aws_guardduty_publishing_destination" "s3" {
  count           = var.enable_findings_export ? 1 : 0
  detector_id     = aws_guardduty_detector.main.id
  destination_arn = "arn:aws:s3:::${var.log_archive_bucket_name}/guardduty"
  kms_key_arn     = var.log_archive_kms_key_arn

  depends_on = [
    aws_guardduty_detector.main,
    aws_s3_object.guardduty_prefix
  ]
}

# -----------------------------------------------------------
# ORG-WIDE AUTO-ENABLE
# Automatically enables GuardDuty in all new accounts
# New accounts added to Organization are immediately protected
# -----------------------------------------------------------
resource "aws_guardduty_organization_configuration" "main" {
  auto_enable_organization_members = var.enable_org_auto_enable ? "ALL" : "NONE"
  detector_id                      = aws_guardduty_detector.main.id

  datasources {
    s3_logs {
      auto_enable = var.enable_s3_protection
    }
    kubernetes {
      audit_logs {
        enable = var.enable_eks_protection
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          auto_enable = var.enable_malware_protection
        }
      }
    }
  }
}

# -----------------------------------------------------------
# MEMBER ACCOUNT ENROLLMENT
# Enrolls existing member accounts in org-wide GuardDuty
# New accounts auto-enrolled via organization_configuration
# -----------------------------------------------------------
resource "aws_guardduty_member" "audit" {
  count       = contains(var.member_accounts, var.audit_account_id) ? 1 : 0
  detector_id = aws_guardduty_detector.main.id
  account_id  = var.audit_account_id
  email       = "mwangi.maina83+audit@gmail.com"
  invite      = true

  lifecycle {
    ignore_changes = [email]
  }
}

# -----------------------------------------------------------
# HIGH SEVERITY FINDING ALERT
# Fires within 1 hour of a high severity finding
# Routes to SNS → email/PagerDuty/Teams
# When Sentinel is connected this becomes redundant
# but provides immediate alerting during transition
# -----------------------------------------------------------
resource "aws_sns_topic" "guardduty_alerts" {
  count = var.security_alert_topic_arn == "" ? 1 : 0
  name  = "${var.project_prefix}-guardduty-alerts"

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-guardduty-alerts"
    Purpose = "High severity GuardDuty finding alerts"
  })
}

resource "aws_sns_topic_subscription" "guardduty_alert_email" {
  count     = var.security_alert_topic_arn == "" ? 1 : 0
  topic_arn = aws_sns_topic.guardduty_alerts[0].arn
  protocol  = "email"
  endpoint  = var.security_alert_email
}

locals {
  alert_topic_arn = var.security_alert_topic_arn != "" ? var.security_alert_topic_arn : (
    length(aws_sns_topic.guardduty_alerts) > 0 ? aws_sns_topic.guardduty_alerts[0].arn : ""
  )
}

# EventBridge rule — catches high severity findings
resource "aws_cloudwatch_event_rule" "guardduty_high_severity" {
  name        = "${var.project_prefix}-guardduty-high-severity"
  description = "Captures GuardDuty findings with severity >= ${var.high_severity_threshold}"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", var.high_severity_threshold] }]
    }
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_prefix}-guardduty-high-severity"
  })
}

resource "aws_cloudwatch_event_target" "guardduty_sns" {
  rule      = aws_cloudwatch_event_rule.guardduty_high_severity.name
  target_id = "GuardDutySNS"
  arn       = local.alert_topic_arn

  input_transformer {
    input_paths = {
      severity    = "$.detail.severity"
      type        = "$.detail.type"
      account     = "$.detail.accountId"
      region      = "$.region"
      description = "$.detail.description"
      time        = "$.time"
    }
    input_template = <<-EOT
      "GUARDDUTY ALERT"
      "Severity: <severity>"
      "Type: <type>"
      "Account: <account>"
      "Region: <region>"
      "Time: <time>"
      "Description: <description>"
      "Action: Review in GuardDuty console and Sentinel immediately"
    EOT
  }
}

# SNS topic policy — allows EventBridge to publish
resource "aws_sns_topic_policy" "guardduty_alerts" {
  count = var.security_alert_topic_arn == "" ? 1 : 0
  arn   = aws_sns_topic.guardduty_alerts[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgePublish"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.guardduty_alerts[0].arn
      }
    ]
  })
}

# -----------------------------------------------------------
# CLOUDWATCH METRIC ALARM
# Tracks finding count — spike indicates active attack
# -----------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "guardduty_findings_spike" {
  alarm_name          = "${var.project_prefix}-guardduty-findings-spike"
  alarm_description   = "GuardDuty finding count spike — possible active attack or reconnaissance"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FindingCount"
  namespace           = "GuardDutyFindingCount"
  period              = 3600
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"

  alarm_actions = [local.alert_topic_arn]

  tags = merge(var.common_tags, {
    Name     = "${var.project_prefix}-guardduty-findings-spike"
    Severity = "HIGH"
  })
}