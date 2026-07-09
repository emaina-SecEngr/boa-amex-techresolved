# ============================================================
# main.tf — Break Glass alarm and Identity Center data sources
# Module: iam-identity-center
#
# This file handles:
# 1. Break Glass CloudWatch alarm — fires when BreakGlass
#    permission set is used by anyone
# 2. Data sources for Identity Center instance
# 3. Entra ID connection (when deploy_entra_id_connection=true)
#
# SCPs are in scps.tf
# Permission Sets are in permission_sets.tf
# ============================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------
# BREAK GLASS ALARM
# Fires the moment anyone uses the BreakGlass permission set
# This is NOT optional — every Break Glass use must be
# immediately visible to the security team and CISO
#
# How it works:
# CloudTrail logs every AssumeRoleWithSAML call
# When the BreakGlass permission set is assumed, CloudTrail
# records the event with the permission set name in the ARN
# The metric filter catches this specific pattern
# The alarm fires within 60 seconds
# SNS delivers to CISO email immediately
# -----------------------------------------------------------
resource "aws_sns_topic" "break_glass_alerts" {
  count = var.deploy_identity_center && var.break_glass_sns_topic_arn == "" ? 1 : 0

  name = "${var.project_prefix}-break-glass-alerts"

  tags = merge(var.common_tags, {
    Name     = "${var.project_prefix}-break-glass-alerts"
    Severity = "CRITICAL"
    Purpose  = "Immediate notification when BreakGlass access is used"
  })
}

locals {
  break_glass_topic_arn = var.break_glass_sns_topic_arn != "" ? var.break_glass_sns_topic_arn : (
    var.deploy_identity_center ? aws_sns_topic.break_glass_alerts[0].arn : ""
  )
}

resource "aws_sns_topic_subscription" "break_glass_email" {
  count = var.deploy_identity_center && var.break_glass_sns_topic_arn == "" ? 1 : 0

  topic_arn = aws_sns_topic.break_glass_alerts[0].arn
  protocol  = "email"
  endpoint  = var.break_glass_alert_email
}

# CloudWatch Log Group for CloudTrail events
# Used by the Break Glass metric filter
resource "aws_cloudwatch_log_group" "break_glass" {
  count = var.deploy_identity_center ? 1 : 0

  name              = "/aws/identity-center/break-glass"
  retention_in_days = 365

  tags = merge(var.common_tags, {
    Name    = "/aws/identity-center/break-glass"
    Purpose = "Break Glass usage detection via CloudTrail metric filter"
  })
}

# Metric filter — detects BreakGlass permission set assumption
resource "aws_cloudwatch_log_metric_filter" "break_glass" {
  count = var.deploy_identity_center ? 1 : 0

  name           = "${var.project_prefix}-break-glass-usage"
  log_group_name = aws_cloudwatch_log_group.break_glass[0].name

  # Matches any AssumeRoleWithSAML where the role name
  # contains "BreakGlass" — the exact string Identity Center
  # uses when creating the role for this permission set
  pattern = "{ $.eventName = \"AssumeRoleWithSAML\" && $.requestParameters.roleArn = \"*BreakGlass*\" }"

  metric_transformation {
    name          = "BreakGlassUsageCount"
    namespace     = "${var.project_prefix}/IdentityCenter"
    value         = "1"
    default_value = "0"
  }
}

# CloudWatch alarm — triggers within 60 seconds of Break Glass use
resource "aws_cloudwatch_metric_alarm" "break_glass" {
  count = var.deploy_identity_center ? 1 : 0

  alarm_name          = "${var.project_prefix}-break-glass-used"
  alarm_description   = "CRITICAL: BreakGlass emergency access was used. Immediate review required. Who used it, why, and what actions were taken must be documented within 24 hours per OCC requirements."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "BreakGlassUsageCount"
  namespace           = "${var.project_prefix}/IdentityCenter"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  alarm_actions = [local.break_glass_topic_arn]
  ok_actions    = [local.break_glass_topic_arn]

  tags = merge(var.common_tags, {
    Name     = "${var.project_prefix}-break-glass-used"
    Severity = "CRITICAL"
  })
}

# -----------------------------------------------------------
# ACCOUNT ASSIGNMENTS
# Assigns Permission Sets to specific accounts
# These are the actual access grants — who can log into
# which account with which permission set
#
# NOTE: Without Entra ID groups provisioned via SCIM,
# these assignments reference group IDs that must exist
# in Identity Center. Once SCIM syncs groups from Entra ID,
# we reference those group IDs here.
#
# For now: assignments are structured but commented out
# until Entra ID groups are provisioned via SCIM.
# Uncomment and add group IDs after SCIM sync completes.
# -----------------------------------------------------------

# Example — uncomment after SCIM sync creates groups:
#
# resource "aws_ssoadmin_account_assignment" "security_auditor_security_tooling" {
#   count = var.deploy_identity_center ? 1 : 0
#
#   instance_arn       = local.sso_instance_arn
#   permission_set_arn = aws_ssoadmin_permission_set.security_auditor[0].arn
#
#   principal_id   = "ENTRA_ID_GROUP_ID_FROM_SCIM"
#   principal_type = "GROUP"
#
#   target_id   = var.security_tooling_account_id
#   target_type = "AWS_ACCOUNT"
# }