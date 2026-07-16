# ============================================================
# outputs.tf — Exported values from sentinel module
# ============================================================

output "sentinel_reader_role_arn" {
  description = "IAM role ARN for Sentinel — paste into Azure Sentinel AWS S3 connector"
  value       = var.enable_sentinel ? aws_iam_role.sentinel_reader[0].arn : "NOT CREATED - enable_sentinel = false"
}

output "sqs_queue_urls" {
  description = "SQS queue URLs — paste into each Sentinel data connector"
  value = {
    cloudtrail    = var.enable_sentinel && var.enable_cloudtrail_connector ? aws_sqs_queue.sentinel_cloudtrail[0].url : "NOT CREATED"
    guardduty     = var.enable_sentinel && var.enable_guardduty_connector ? aws_sqs_queue.sentinel_guardduty[0].url : "NOT CREATED"
    security_hub  = var.enable_sentinel && var.enable_security_hub_connector ? aws_sqs_queue.sentinel_security_hub[0].url : "NOT CREATED"
    vpc_flow_logs = var.enable_sentinel && var.enable_vpc_flow_logs_connector ? aws_sqs_queue.sentinel_vpc_flow_logs[0].url : "NOT CREATED"
  }
}

output "sentinel_status" {
  description = "Sentinel connector configuration summary"
  value = {
    enabled            = var.enable_sentinel
    reader_role        = var.enable_sentinel ? "CREATED" : "NOT CREATED - enable_sentinel = false"
    cloudtrail_queue   = var.enable_sentinel && var.enable_cloudtrail_connector ? "CREATED" : "NOT CREATED"
    guardduty_queue    = var.enable_sentinel && var.enable_guardduty_connector ? "CREATED" : "NOT CREATED"
    security_hub_queue = var.enable_sentinel && var.enable_security_hub_connector ? "CREATED" : "NOT CREATED"
    vpc_flow_logs_queue = var.enable_sentinel && var.enable_vpc_flow_logs_connector ? "CREATED" : "NOT CREATED"
    azure_subscription = "DISABLED - restore Azure for Students subscription first"
  }
}

output "sentinel_activation_instructions" {
  description = "Complete step-by-step to activate Sentinel when Azure is restored"
  value       = <<-EOT
    When Azure student subscription is restored:

    STEP 1 - Create Sentinel workspace in Azure:
      Azure Portal → Create resource → Microsoft Sentinel
      → Create new Log Analytics workspace
      → Name: boa-amex-sentinel
      → Region: East US (closest to AWS us-east-1)
      → Add Sentinel to workspace

    STEP 2 - Get workspace credentials:
      Azure Portal → Sentinel → Settings → Workspace settings
      → Copy: Workspace ID
      Azure Portal → Log Analytics → Agents
      → Copy: Primary key

    STEP 3 - Update Terraform:
      In environments/security-tooling/main.tf:
        enable_sentinel = true
        sentinel_workspace_id = "WORKSPACE_ID"
        sentinel_workspace_key = "PRIMARY_KEY"
      Run: terraform apply

    STEP 4 - Configure AWS connectors in Sentinel:
      Azure Portal → Sentinel → Data connectors
      → Amazon Web Services S3
      → Paste IAM role ARN from terraform output
      → Paste SQS queue URLs for each data source
      → Test connectivity

    STEP 5 - Enable analytics rules:
      Azure Portal → Sentinel → Analytics
      → Rule templates → filter "AWS"
      → Enable: AWS CloudTrail - Unusual Activity
      → Enable: AWS GuardDuty - High Severity
      → Enable: Suspicious AWS S3 activity
      → Create custom rules for BOA-AMEX patterns

    STEP 6 - Configure SOAR playbooks:
      Azure Portal → Sentinel → Automation
      → Create playbook (Logic App)
      → Trigger: When Sentinel incident is created
      → Actions: Isolate EC2, revoke IAM, alert Teams

    STEP 7 - Verify end-to-end:
      Generate test GuardDuty finding
      Verify it appears in Sentinel within 5 minutes
      Verify analytics rule fires
      Verify incident created
      Verify playbook responds
  EOT
}

output "occ_evidence_note" {
  description = "OCC examination evidence this module provides"
  value       = "Satisfies: OCC unified SIEM requirement, PCI-DSS Req 10.6 (centralized log review), PCI-DSS Req 10.7 (retain audit trail history). Microsoft Sentinel provides unified SIEM correlation across all AWS security data sources with automated analytics rules and SOAR playbook response."
}