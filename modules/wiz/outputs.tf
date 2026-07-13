# ============================================================
# outputs.tf — Exported values from wiz module
# ============================================================

output "wiz_scanner_role_arn" {
  description = "WizScanner IAM role ARN — paste into Wiz console connector setup"
  value       = var.enable_wiz_scanner ? aws_iam_role.wiz_scanner[0].arn : ""
}

output "wiz_scanner_role_name" {
  description = "WizScanner IAM role name"
  value       = var.enable_wiz_scanner ? aws_iam_role.wiz_scanner[0].name : ""
}

output "wiz_findings_topic_arn" {
  description = "SNS topic ARN for Wiz critical findings"
  value       = var.enable_wiz_scanner ? aws_sns_topic.wiz_findings[0].arn : ""
}

output "wiz_status" {
  description = "Wiz configuration summary"
  value = {
    scanner_role  = var.enable_wiz_scanner ? "CREATED — arn:aws:iam::${var.security_tooling_account_id}:role/WizScanner" : "DISABLED"
    cspm_scanning = var.enable_cspm_scanning ? "ENABLED" : "DISABLED"
    cwpp_scanning = var.enable_cwpp_scanning ? "ENABLED" : "DISABLED"
    ciem_scanning = var.enable_ciem_scanning ? "ENABLED" : "DISABLED"
    data_scanning = var.enable_data_scanning ? "ENABLED" : "DISABLED"
    kms_grants    = var.enable_kms_grants ? "ENABLED" : "DISABLED"
    trial_status  = "Contact sales@wiz.io for 30-day trial"
  }
}

output "wiz_connector_setup_instructions" {
  description = "Steps to connect Wiz console to your AWS accounts"
  value       = <<-EOT
    Wiz Connector Setup (after obtaining trial):
    1. Go to Wiz console → Settings → Connectors
    2. Add connector → AWS
    3. Select: Organization connector
    4. Enter Management account ID: 682391277575
    5. Enter WizScanner role ARN:
       arn:aws:iam::368351959735:role/WizScanner
    6. Enter External ID: WIZ-BOA-AMEX-SCANNER
    7. Wiz performs initial scan (2-4 hours)
    8. Findings appear in Wiz Security Graph
    9. Configure alert routing:
       Wiz console → Integrations → AWS Security Hub
       → Findings flow into Security Hub → Sentinel
  EOT
}

output "occ_evidence_note" {
  description = "OCC examination evidence this module provides"
  value       = "Satisfies: OCC CSPM requirement (continuous misconfiguration detection), PCI-DSS Req 6.3 (vulnerability management), PCI-DSS Req 11.3 (external vulnerability scanning). Wiz Security Graph provides attack path analysis connecting misconfigurations, vulnerabilities, and identity risks across all accounts."
}