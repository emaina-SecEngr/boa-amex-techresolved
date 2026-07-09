# ============================================================
# main.tf — Management account baseline security configuration
# Module: management-baseline
#
# DEPLOYMENT ACCOUNT: Management (682391277575)
# PREREQUISITE: aws-organization module complete
# ============================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------
# LOCAL VALUES
# -----------------------------------------------------------
locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  cloudtrail_name = "${var.project_prefix}-org-trail"
}

# -----------------------------------------------------------
# COMPONENT 1 — ORG-WIDE CLOUDTRAIL
#
# This is NOT a per-account trail — it is an ORGANIZATION
# trail that captures events from EVERY account automatically.
#
# Key difference from per-account CloudTrail:
#   Per-account: member account admins can disable it
#   Org trail:   only Management account can modify it
#                member accounts have NO permissions here
#
# The trail delivers logs to the Log Archive bucket in
# Security Tooling account — using the existing bucket
# we built in amex-log-archive until Phase 2 creates
# the production bucket in BOA-AMEX-TechResolved
# -----------------------------------------------------------
resource "aws_cloudtrail" "organization" {
  count = var.enable_org_cloudtrail ? 1 : 0

  name           = local.cloudtrail_name
  s3_bucket_name = var.cloudtrail_log_bucket_name
  s3_key_prefix  = var.cloudtrail_log_prefix

  # Org trail — covers ALL accounts automatically
  is_organization_trail = true

  # Multi-region — captures events from ALL regions
  # Attackers often use non-primary regions to evade detection
  is_multi_region_trail = var.cloudtrail_multi_region

  # Global services — IAM, STS, Route 53
  # These are the most security-critical event types
  include_global_service_events = var.cloudtrail_include_global_events

  # SHA-256 log file validation
  # Creates digest files allowing tamper detection
  # Required for OCC and PCI-DSS compliance
  enable_log_file_validation = var.cloudtrail_log_file_validation

  # KMS encryption — use CMK if provided
  # Falls back to SSE-S3 if no KMS key specified
  kms_key_id = var.cloudtrail_kms_key_arn != "" ? var.cloudtrail_kms_key_arn : null

  # S3 data events — significantly increases cost
  # Enable only if S3 stores cardholder or sensitive data
  dynamic "event_selector" {
    for_each = var.cloudtrail_s3_data_events ? [1] : []
    content {
      read_write_type           = "All"
      include_management_events = true

      data_resource {
        type   = "AWS::S3::Object"
        values = ["arn:aws:s3:::"]
      }
    }
  }

  # Lambda data events — enable when Lambda processes
  # sensitive data requiring audit trail
  dynamic "event_selector" {
    for_each = var.cloudtrail_lambda_data_events ? [1] : []
    content {
      read_write_type           = "All"
      include_management_events = true

      data_resource {
        type   = "AWS::Lambda::Function"
        values = ["arn:aws:lambda"]
      }
    }
  }

  # Default event selector when no data events enabled
  dynamic "event_selector" {
    for_each = !var.cloudtrail_s3_data_events && !var.cloudtrail_lambda_data_events ? [1] : []
    content {
      read_write_type           = "All"
      include_management_events = true
    }
  }

  tags = merge(var.common_tags, {
    Name    = local.cloudtrail_name
    Purpose = "Org-wide CloudTrail - all accounts and all regions - tamper-proof"
  })
}

# -----------------------------------------------------------
# COMPONENT 2 — CONFIG AGGREGATOR
#
# Pulls AWS Config compliance data from ALL accounts
# in the Organization into one central view.
#
# Two resources required:
#   1. aws_config_configuration_aggregator (in Management)
#      The aggregator that pulls data centrally
#   2. aws_config_aggregate_authorization (in each member account)
#      Grants permission for aggregator to pull their data
#      NOTE: For ORG aggregators, AWS handles authorization
#      automatically — no per-account resource needed
# -----------------------------------------------------------
resource "aws_config_configuration_aggregator" "organization" {
  count = var.enable_config_aggregator ? 1 : 0

  name = "${var.project_prefix}-org-config-aggregator"

  # Organization aggregator — pulls from ALL accounts
  # automatically including new accounts added later
  organization_aggregation_source {
    all_regions = true
    role_arn    = aws_iam_role.config_aggregator[0].arn
  }

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-org-config-aggregator"
    Purpose = "Central Config compliance view across all Organization accounts"
  })

  depends_on = [aws_iam_role_policy_attachment.config_aggregator]
}

# IAM role for Config aggregator
# Needs permission to read Config data from member accounts
resource "aws_iam_role" "config_aggregator" {
  count = var.enable_config_aggregator ? 1 : 0

  name = "${var.project_prefix}-config-aggregator-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-config-aggregator-role"
    Purpose = "Config aggregator cross-account read access"
  })
}

resource "aws_iam_role_policy_attachment" "config_aggregator" {
  count      = var.enable_config_aggregator ? 1 : 0
  role       = aws_iam_role.config_aggregator[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRoleForOrganizations"
}

# -----------------------------------------------------------
# COMPONENT 3 — ROOT ACCOUNT PROTECTION
#
# Two separate controls:
#   a. CloudWatch alarm fires when root is used
#   b. SNS notification delivered to security team
#
# Note: The SCP DenyRootUsage (preventing root login in
# member accounts) is in modules/iam-identity-center/
# This component handles the DETECTION side —
# the SCP handles the PREVENTION side
# -----------------------------------------------------------

# SNS topic for security alerts in Management account
resource "aws_sns_topic" "security_alerts" {
  count = var.enable_root_usage_alarm ? 1 : 0

  name = "${var.project_prefix}-mgmt-security-alerts"

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-mgmt-security-alerts"
    Purpose = "Management account security alerts - root usage and critical findings"
  })
}

resource "aws_sns_topic_subscription" "security_alert_email" {
  count = var.enable_root_usage_alarm ? 1 : 0

  topic_arn = aws_sns_topic.security_alerts[0].arn
  protocol  = "email"
  endpoint  = var.security_alert_email
}

# CloudWatch metric filter — detects root account usage
# in CloudTrail logs flowing through CloudWatch Logs
resource "aws_cloudwatch_log_group" "cloudtrail" {
  count = var.enable_root_usage_alarm ? 1 : 0

  name              = "/aws/cloudtrail/${local.cloudtrail_name}"
  retention_in_days = 365

  tags = merge(var.common_tags, {
    Name    = "/aws/cloudtrail/${local.cloudtrail_name}"
    Purpose = "CloudTrail logs for real-time metric filtering"
  })
}

resource "aws_iam_role" "cloudtrail_cloudwatch" {
  count = var.enable_root_usage_alarm ? 1 : 0

  name = "${var.project_prefix}-cloudtrail-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_prefix}-cloudtrail-cloudwatch-role"
  })
}

resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  count = var.enable_root_usage_alarm ? 1 : 0

  name = "${var.project_prefix}-cloudtrail-cloudwatch-policy"
  role = aws_iam_role.cloudtrail_cloudwatch[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "${aws_cloudwatch_log_group.cloudtrail[0].arn}:*"
    }]
  })
}

# Metric filter — watches for root account usage events
resource "aws_cloudwatch_log_metric_filter" "root_usage" {
  count = var.enable_root_usage_alarm ? 1 : 0

  name           = "${var.project_prefix}-root-account-usage"
  log_group_name = aws_cloudwatch_log_group.cloudtrail[0].name

  # This filter pattern matches any CloudTrail event
  # where the userIdentity type is Root
  # Fires on ANY root account activity — login, API call, console
  pattern = "{ $.userIdentity.type = \"Root\" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != \"AwsServiceEvent\" }"

  metric_transformation {
    name          = "RootAccountUsageCount"
    namespace     = "${var.project_prefix}/SecurityMetrics"
    value         = "1"
    default_value = "0"
  }
}

# CloudWatch alarm — triggers SNS when root is used
resource "aws_cloudwatch_metric_alarm" "root_usage" {
  count = var.enable_root_usage_alarm ? 1 : 0

  alarm_name          = "${var.project_prefix}-root-account-usage-detected"
  alarm_description   = "CRITICAL: Root account credentials used. Immediate investigation required. OCC requirement: root usage must be rare, justified, and reviewed."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "RootAccountUsageCount"
  namespace           = "${var.project_prefix}/SecurityMetrics"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.security_alerts[0].arn]
  ok_actions    = [aws_sns_topic.security_alerts[0].arn]

  tags = merge(var.common_tags, {
    Name     = "${var.project_prefix}-root-account-usage-detected"
    Severity = "CRITICAL"
    Purpose  = "Root account usage detection - OCC and PCI-DSS requirement"
  })
}

# -----------------------------------------------------------
# COMPONENT 4 — IAM PASSWORD POLICY
# Applies to IAM users IN the Management account
# Identity Center (Phase 1 Module 3) handles workload
# account identity via Entra ID — no IAM users there
# -----------------------------------------------------------
resource "aws_iam_account_password_policy" "management" {
  minimum_password_length        = var.password_minimum_length
  require_uppercase_characters   = var.password_require_uppercase
  require_lowercase_characters   = var.password_require_lowercase
  require_numbers                = var.password_require_numbers
  require_symbols                = var.password_require_symbols
  allow_users_to_change_password = var.allow_users_to_change_password
  max_password_age               = var.password_max_age_days
  password_reuse_prevention      = var.password_reuse_prevention
  hard_expiry                    = var.hard_expiry
}