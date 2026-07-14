# ============================================================
# outputs.tf — Exported values from crowdstrike module
# ============================================================

output "falcon_horizon_role_arn" {
  description = "CrowdStrike Falcon Horizon IAM role ARN — paste into Falcon console CSPM connector setup"
  value       = var.enable_crowdstrike && var.enable_falcon_horizon ? aws_iam_role.falcon_horizon[0].arn : ""
}

output "fdr_bucket_name" {
  description = "Falcon Data Replicator S3 bucket name — provide to CrowdStrike for FDR delivery setup"
  value       = var.enable_crowdstrike && var.enable_fdr ? aws_s3_bucket.crowdstrike_fdr[0].id : ""
}

output "fdr_bucket_arn" {
  description = "Falcon Data Replicator S3 bucket ARN"
  value       = var.enable_crowdstrike && var.enable_fdr ? aws_s3_bucket.crowdstrike_fdr[0].arn : ""
}

output "fdr_processor_lambda_arn" {
  description = "Lambda function ARN that normalizes CrowdStrike FDR data to OCSF"
  value       = var.enable_crowdstrike && var.enable_fdr ? aws_lambda_function.fdr_processor[0].arn : ""
}

output "fdr_processor_lambda_name" {
  description = "Lambda function name for the FDR OCSF processor"
  value       = var.enable_crowdstrike && var.enable_fdr ? aws_lambda_function.fdr_processor[0].function_name : ""
}

output "crowdstrike_alerts_topic_arn" {
  description = "SNS topic ARN for critical CrowdStrike detections"
  value       = local.alert_topic_arn
}

output "crowdstrike_status" {
  description = "CrowdStrike configuration summary"
  value = {
    falcon_horizon     = var.enable_crowdstrike && var.enable_falcon_horizon ? "CREATED — arn:aws:iam::${var.security_tooling_account_id}:role/CrowdStrikeFalconHorizon" : "DISABLED"
    sensor_deployment  = var.enable_crowdstrike && var.enable_sensor_deployment ? "ENABLED" : "DISABLED"
    fdr                = var.enable_crowdstrike && var.enable_fdr ? "ENABLED — ${var.fdr_bucket_name}" : "DISABLED"
    edr                = var.enable_crowdstrike && var.enable_edr ? "ENABLED" : "DISABLED"
    identity_protection = var.enable_crowdstrike && var.enable_identity_protection ? "ENABLED" : "DISABLED"
    container_security = var.enable_crowdstrike && var.enable_container_security ? "ENABLED" : "DISABLED"
    trial_status       = "Contact CrowdStrike for 15-day trial — crowdstrike.com/free-trial"
  }
}

output "crowdstrike_connector_setup_instructions" {
  description = "Steps to connect Falcon console to your AWS accounts"
  value       = <<-EOT
    CrowdStrike Falcon Setup (after obtaining trial/CID):
    1. Go to Falcon console → Host Setup and Management → Sensor Downloads
    2. Copy your CID → set as crowdstrike_cid in terraform.tfvars
    3. Go to Falcon console → Cloud Security → AWS → Add Account
    4. Enter Falcon Horizon role ARN:
       arn:aws:iam::${var.security_tooling_account_id}:role/CrowdStrikeFalconHorizon
    5. Enter External ID: CS-BOA-AMEX-HORIZON
    6. Go to Falcon console → Data Replicator (FDR) → Add S3 Destination
    7. Enter FDR bucket name: ${var.fdr_bucket_name}
    8. terraform apply — SSM Association installs sensor on all EC2 instances
    9. FDR data lands in S3 → Lambda normalizes to OCSF → Security Lake → Sentinel
  EOT
}

output "occ_evidence_note" {
  description = "OCC examination evidence this module provides"
  value       = "Satisfies: OCC endpoint detection and response requirement, PCI-DSS Req 5 (malware protection), PCI-DSS Req 10 (endpoint activity logging and monitoring), PCI-DSS Req 11.5 (intrusion detection). CrowdStrike Falcon provides EDR, CSPM, and identity protection across all endpoints, with telemetry normalized to OCSF and routed to Security Lake for centralized analysis."
}
