# ============================================================
# outputs.tf — Exported values from log-archive module
# ============================================================

output "log_archive_bucket_name" {
  description = "Log archive S3 bucket name — referenced by all other Phase 2 modules"
  value       = aws_s3_bucket.log_archive.id
}

output "log_archive_bucket_arn" {
  description = "Log archive S3 bucket ARN"
  value       = aws_s3_bucket.log_archive.arn
}

output "log_archive_kms_key_arn" {
  description = "KMS key ARN for log archive encryption — referenced by GuardDuty, CloudTrail, Config"
  value       = aws_kms_key.log_archive.arn
}

output "log_archive_kms_key_id" {
  description = "KMS key ID"
  value       = aws_kms_key.log_archive.key_id
}

output "log_archive_kms_alias" {
  description = "KMS key alias"
  value       = aws_kms_alias.log_archive.name
}

output "log_archive_alerts_topic_arn" {
  description = "SNS topic ARN for log archive security alerts"
  value       = aws_sns_topic.log_archive_alerts.arn
}

output "sentinel_integration_status" {
  description = "Microsoft Sentinel integration status"
  value       = var.enable_sentinel_integration ? "ENABLED — logs flowing to Sentinel workspace" : "DISABLED — flip enable_sentinel_integration=true when Azure subscription is active"
}

output "log_archive_status" {
  description = "Summary of log archive configuration"
  value = {
    bucket_name        = aws_s3_bucket.log_archive.id
    object_lock        = var.enable_object_lock ? "ENABLED — COMPLIANCE mode ${var.object_lock_retention_days} days" : "DISABLED"
    encryption         = "AWS KMS CMK — ${aws_kms_alias.log_archive.name}"
    versioning         = var.enable_versioning ? "ENABLED" : "DISABLED"
    lifecycle          = "Standard(${var.standard_retention_days}d) → GlacierIR(${var.glacier_instant_retention_days}d) → DeepArchive(${var.glacier_deep_archive_retention_days}d)"
    sentinel_connected = var.enable_sentinel_integration ? "YES" : "NO — pending Azure subscription"
  }
}

output "verify_bucket_command" {
  description = "Verify log archive bucket configuration"
  value       = "aws s3api get-bucket-versioning --bucket ${aws_s3_bucket.log_archive.id} && aws s3api get-object-lock-configuration --bucket ${aws_s3_bucket.log_archive.id}"
}

output "verify_encryption_command" {
  description = "Verify KMS encryption is configured"
  value       = "aws s3api get-bucket-encryption --bucket ${aws_s3_bucket.log_archive.id} --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault'"
}

output "occ_evidence_note" {
  description = "OCC examination evidence this module provides"
  value       = "Satisfies: OCC immutable audit trail requirement (Object Lock COMPLIANCE), PCI-DSS Req 10.5 (protect audit trails), PCI-DSS Req 3.5 (encrypt stored data), 7-year retention policy"
}