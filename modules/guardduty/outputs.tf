# ============================================================
# outputs.tf — Exported values from guardduty module
# ============================================================

output "detector_id" {
  description = "GuardDuty detector ID"
  value       = aws_guardduty_detector.main.id
}

output "detector_arn" {
  description = "GuardDuty detector ARN"
  value       = "arn:aws:guardduty:${local.region}:${local.account_id}:detector/${aws_guardduty_detector.main.id}"
}

output "guardduty_alerts_topic_arn" {
  description = "SNS topic ARN for high severity GuardDuty finding alerts"
  value       = local.alert_topic_arn
}

output "guardduty_status" {
  description = "Summary of GuardDuty configuration"
  value = {
    enabled            = var.enable_guardduty ? "ENABLED" : "DISABLED"
    finding_frequency  = var.finding_publishing_frequency
    s3_protection      = var.enable_s3_protection ? "ENABLED" : "DISABLED"
    eks_protection     = var.enable_eks_protection ? "ENABLED" : "DISABLED"
    malware_protection = var.enable_malware_protection ? "ENABLED" : "DISABLED"
    rds_protection     = var.enable_rds_protection ? "ENABLED" : "DISABLED"
    lambda_protection  = var.enable_lambda_protection ? "ENABLED" : "DISABLED"
    runtime_monitoring = var.enable_runtime_monitoring ? "ENABLED" : "DISABLED"
    org_auto_enable    = var.enable_org_auto_enable ? "ENABLED — new accounts auto-protected" : "DISABLED"
    findings_export    = var.enable_findings_export ? "ENABLED — exporting to Log Archive bucket" : "DISABLED"
    sentinel_connected = var.enable_sentinel_integration ? "YES" : "NO — pending Azure subscription"
  }
}

output "verify_detector_command" {
  description = "Verify GuardDuty detector configuration"
  value       = "aws guardduty get-detector --detector-id ${aws_guardduty_detector.main.id} --query '{Status:Status,Frequency:FindingPublishingFrequency}' --output table"
}

output "occ_evidence_note" {
  description = "OCC examination evidence this module provides"
  value       = "Satisfies: OCC continuous monitoring requirement (org-wide GuardDuty, auto-enabled for new accounts), PCI-DSS Req 5 (malicious activity detection), 15-minute finding publishing frequency for timely alerting"
}
