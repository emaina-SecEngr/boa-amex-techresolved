# ============================================================
# outputs.tf — Exported values from management-baseline module
# ============================================================

output "org_cloudtrail_arn" {
  description = "Organization-wide CloudTrail ARN — referenced by compliance reports and OCC evidence packages"
  value       = var.enable_org_cloudtrail ? aws_cloudtrail.organization[0].arn : ""
}

output "org_cloudtrail_name" {
  description = "Organization-wide CloudTrail name"
  value       = var.enable_org_cloudtrail ? aws_cloudtrail.organization[0].name : ""
}

output "org_cloudtrail_home_region" {
  description = "Home region of the org-wide CloudTrail — where the trail is managed from"
  value       = var.enable_org_cloudtrail ? aws_cloudtrail.organization[0].home_region : ""
}

output "config_aggregator_arn" {
  description = "Config aggregator ARN — pulls compliance data from all Organization accounts"
  value       = var.enable_config_aggregator ? aws_config_configuration_aggregator.organization[0].arn : ""
}

output "security_alerts_topic_arn" {
  description = "SNS topic ARN for Management account security alerts including root usage"
  value       = var.enable_root_usage_alarm ? aws_sns_topic.security_alerts[0].arn : ""
}

output "cloudtrail_log_group_name" {
  description = "CloudWatch Log Group receiving CloudTrail events for metric filtering"
  value       = var.enable_root_usage_alarm ? aws_cloudwatch_log_group.cloudtrail[0].name : ""
}

output "baseline_status" {
  description = "Summary of Management Baseline component deployment status"
  value = {
    org_cloudtrail    = var.enable_org_cloudtrail ? "ENABLED — capturing all accounts all regions" : "DISABLED"
    config_aggregator = var.enable_config_aggregator ? "ENABLED — aggregating compliance from all accounts" : "DISABLED"
    root_usage_alarm  = var.enable_root_usage_alarm ? "ENABLED — alarm fires within 60 seconds of root usage" : "DISABLED"
    password_policy   = "APPLIED — ${var.password_minimum_length} char min, ${var.password_max_age_days} day max age"
  }
}

output "verify_cloudtrail_command" {
  description = "Verify org-wide CloudTrail is active and covering all accounts"
  value       = var.enable_org_cloudtrail ? "aws cloudtrail describe-trails --include-shadow-trails --query 'trailList[?IsOrganizationTrail==`true`].{Name:Name,IsOrg:IsOrganizationTrail,MultiRegion:IsMultiRegionTrail,HomeRegion:HomeRegion}' --output table" : "CloudTrail not enabled"
}

output "verify_config_aggregator_command" {
  description = "Verify Config aggregator is pulling from all accounts"
  value       = var.enable_config_aggregator ? "aws configservice describe-configuration-aggregators --query 'ConfigurationAggregators[].{Name:ConfigurationAggregatorName,Arn:ConfigurationAggregatorArn}' --output table" : "Config aggregator not enabled"
}

output "verify_root_alarm_command" {
  description = "Verify root account usage alarm is configured"
  value       = var.enable_root_usage_alarm ? "aws cloudwatch describe-alarms --alarm-names ${var.project_prefix}-root-account-usage-detected --query 'MetricAlarms[].{Name:AlarmName,State:StateValue,Threshold:Threshold}' --output table" : "Root alarm not enabled"
}

output "verify_password_policy_command" {
  description = "Verify IAM password policy is applied"
  value       = "aws iam get-account-password-policy --query 'PasswordPolicy.{MinLength:MinimumPasswordLength,MaxAge:MaxPasswordAge,ReuseCount:PasswordReusePrevention}' --output table"
}

output "occ_evidence_note" {
  description = "OCC examination evidence this module provides"
  value       = "This module satisfies: OCC continuous monitoring requirement (org CloudTrail), OCC compliance visibility requirement (Config aggregator), PCI-DSS Req 8.2 (password policy), PCI-DSS Req 10.2 (audit trail cannot be disabled by member accounts)"
}