# ============================================================
# outputs.tf — Exported values from security-hub module
# ============================================================

output "security_hub_account_id" {
  description = "AWS account ID Security Hub is enabled in"
  value       = local.account_id
}

output "security_hub_arn" {
  description = "Security Hub ARN (hub/default) for this account"
  value       = aws_securityhub_account.main.arn
}

output "enabled_standards" {
  description = "Human-readable list of compliance standards currently enabled"
  value = compact([
    var.enable_cis_standard ? "CIS AWS Foundations Benchmark v1.4.0" : "",
    var.enable_pci_dss_standard ? "PCI-DSS v3.2.1" : "",
    var.enable_aws_foundational_standard ? "AWS Foundational Security Best Practices v1.0.0" : "",
    var.enable_nist_standard ? "NIST SP 800-53 Rev 5" : "",
  ])
}

output "security_hub_alerts_topic_arn" {
  description = "SNS topic ARN for critical/high severity Security Hub finding alerts"
  value       = aws_sns_topic.security_hub_alerts.arn
}

output "security_hub_status" {
  description = "Summary of Security Hub configuration"
  value = {
    enabled              = var.enable_security_hub ? "ENABLED" : "DISABLED"
    cis_standard         = var.enable_cis_standard ? "ENABLED" : "DISABLED"
    pci_dss_standard     = var.enable_pci_dss_standard ? "ENABLED" : "DISABLED"
    aws_foundational     = var.enable_aws_foundational_standard ? "ENABLED" : "DISABLED"
    nist_standard        = var.enable_nist_standard ? "ENABLED" : "DISABLED"
    finding_aggregation  = var.enable_finding_aggregation ? "ENABLED" : "DISABLED"
    org_auto_enable      = var.enable_org_auto_enable ? "ENABLED — new accounts auto-protected" : "DISABLED"
    critical_alert_email = var.security_alert_email
    sentinel_connected   = var.enable_sentinel_integration ? "YES" : "NO — pending Azure subscription"
  }
}

output "verify_standards_command" {
  description = "Verify enabled Security Hub standards subscriptions"
  value       = "aws securityhub get-enabled-standards --query 'StandardsSubscriptions[].{Standard:StandardsArn,Status:StandardsStatus}' --output table"
}

output "verify_findings_command" {
  description = "Check recent Security Hub findings by severity"
  value       = "aws securityhub get-findings --filters '{\"SeverityLabel\":[{\"Value\":\"CRITICAL\",\"Comparison\":\"EQUALS\"}]}' --query 'Findings[].{Title:Title,Account:AwsAccountId}' --output table"
}

output "occ_evidence_note" {
  description = "OCC examination evidence this module provides"
  value       = "Satisfies: OCC continuous compliance monitoring requirement (CIS/PCI-DSS/AWS-Foundational standards, org-wide auto-enable), PCI-DSS Req 11/12 (security monitoring and controls testing), single pane of glass across GuardDuty/Inspector/Macie/IAM Access Analyzer/Config findings"
}
