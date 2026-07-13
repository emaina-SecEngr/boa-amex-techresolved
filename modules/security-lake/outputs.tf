# ============================================================
# outputs.tf — Exported values from security-lake module
# ============================================================

output "data_lake_arn" {
  description = "Security Lake data lake ARN"
  value       = var.enable_security_lake ? aws_securitylake_data_lake.main[0].arn : ""
}

output "data_lake_s3_bucket_arn" {
  description = "Security Lake S3 bucket ARN — Sentinel reads OCSF data from here"
  value       = var.enable_security_lake ? aws_securitylake_data_lake.main[0].s3_bucket_arn : ""
}

output "sentinel_subscriber_arn" {
  description = "Sentinel subscriber ARN — created when enable_sentinel_integration = true"
  value       = var.enable_sentinel_integration && length(aws_securitylake_subscriber.sentinel) > 0 ? aws_securitylake_subscriber.sentinel[0].arn : "NOT CREATED — enable_sentinel_integration = false"
}

output "security_lake_status" {
  description = "Security Lake configuration summary"
  value = {
    enabled              = var.enable_security_lake
    cloudtrail_source    = var.enable_cloudtrail_source ? "ENABLED" : "DISABLED"
    vpc_flow_logs_source = var.enable_vpc_flow_logs_source ? "ENABLED" : "DISABLED"
    security_hub_source  = var.enable_security_hub_source ? "ENABLED" : "DISABLED"
    route53_source       = var.enable_route53_source ? "ENABLED" : "DISABLED"
    lambda_source        = var.enable_lambda_source ? "ENABLED" : "DISABLED"
    org_sources          = var.enable_org_sources ? "ENABLED — includes ${length(var.member_accounts)} member account(s)" : "DISABLED — Security Tooling account only"
    sentinel_subscriber  = var.enable_sentinel_integration ? "ENABLED" : "DISABLED — pending Azure subscription"
    retention_days       = var.security_lake_retention_days
  }
}

output "security_lake_alerts_topic_arn" {
  description = "SNS topic ARN for Security Lake ingestion spike alerts"
  value       = aws_sns_topic.security_lake_alerts.arn
}

output "sentinel_connection_instructions" {
  description = "Steps to connect Sentinel when Azure subscription is restored"
  value       = <<-EOT
    When Azure subscription is active:
    1. Go to Azure Portal → Microsoft Sentinel
    2. Data Connectors → Amazon Web Services S3
    3. Copy the External ID shown
    4. Set in terraform.tfvars:
         enable_sentinel_integration = true
         sentinel_external_id        = "EXTERNAL_ID_FROM_AZURE"
    5. Run: terraform apply
    6. Get the SQS queue URL — Terraform can't surface it directly
       (aws_securitylake_subscriber_notification exposes no computed
       attribute for it), so retrieve it via:
         aws securitylake get-subscriber --id <subscriber-id> --profile security-tooling
       or AWS Console -> Security Lake -> Subscribers
    7. Paste the queue URL into Sentinel's AWS S3 connector
    8. Sentinel starts ingesting OCSF data within 5 minutes
  EOT
}

output "verify_data_lake_command" {
  description = "Verify Security Lake is active"
  value       = "aws securitylake list-data-lakes --regions us-east-1 --query 'dataLakes[].{Status:createStatus,Region:region}' --output table --profile security-tooling"
}

output "verify_sources_command" {
  description = "Verify log sources are configured"
  value       = "aws securitylake list-log-sources --regions us-east-1 --query 'sources[].{Source:sources[0].awsLogSource.sourceName,Status:sources[0].awsLogSource.sourceVersion}' --output table --profile security-tooling"
}

output "occ_evidence_note" {
  description = "OCC examination evidence this module provides"
  value       = "Satisfies: OCC unified log management requirement. Security Lake normalizes all AWS security logs to OCSF format providing a single queryable data lake for OCC examiners. Enables Sentinel SIEM correlation across CloudTrail, VPC Flow Logs, Security Hub, and DNS logs."
}