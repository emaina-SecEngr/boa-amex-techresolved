# ============================================================
# outputs.tf — Security Tooling environment outputs
# Displays all deployed resource details after terraform apply
# ============================================================

# -----------------------------------------------------------
# LOG ARCHIVE
# -----------------------------------------------------------
output "log_archive_bucket_name" {
  description = "Log archive S3 bucket name"
  value       = module.log_archive.log_archive_bucket_name
}

output "log_archive_bucket_arn" {
  description = "Log archive S3 bucket ARN"
  value       = module.log_archive.log_archive_bucket_arn
}

output "log_archive_kms_key_arn" {
  description = "KMS key ARN — pass to GuardDuty, CloudTrail, Config modules"
  value       = module.log_archive.log_archive_kms_key_arn
}

output "log_archive_status" {
  description = "Log archive full configuration summary"
  value       = module.log_archive.log_archive_status
}

output "sentinel_integration_status" {
  description = "Microsoft Sentinel integration status"
  value       = module.log_archive.sentinel_integration_status
}

output "occ_evidence" {
  description = "OCC examination evidence provided by this environment"
  value       = module.log_archive.occ_evidence_note
}

# -----------------------------------------------------------
# GUARDDUTY
# -----------------------------------------------------------
output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = module.guardduty.detector_id
}

output "guardduty_status" {
  description = "GuardDuty configuration summary"
  value       = module.guardduty.guardduty_status
}

output "guardduty_occ_evidence" {
  description = "OCC evidence from GuardDuty"
  value       = module.guardduty.occ_evidence_note
}

# -----------------------------------------------------------
# SECURITY HUB
# -----------------------------------------------------------
output "security_hub_arn" {
  description = "Security Hub ARN"
  value       = module.security_hub.security_hub_arn
}

output "security_hub_status" {
  description = "Security Hub configuration summary"
  value       = module.security_hub.security_hub_status
}

output "enabled_standards" {
  description = "Compliance standards enabled"
  value       = module.security_hub.enabled_standards
}

output "security_hub_alerts_topic_arn" {
  description = "SNS topic ARN for critical Security Hub findings"
  value       = module.security_hub.security_hub_alerts_topic_arn
}

output "occ_evidence_security_hub" {
  description = "OCC evidence from Security Hub"
  value       = module.security_hub.occ_evidence_note
}

# -----------------------------------------------------------
# VERIFICATION COMMANDS
# Run these after apply to confirm correct state
# -----------------------------------------------------------
output "verify_commands" {
  description = "AWS CLI commands to verify deployed resources"
  value = {
    bucket_versioning = module.log_archive.verify_bucket_command
    kms_encryption    = module.log_archive.verify_encryption_command
    bucket_policy     = "aws s3api get-bucket-policy --bucket ${module.log_archive.log_archive_bucket_name} --output json"
    list_kms_keys     = "aws kms list-aliases --query \"Aliases[?contains(AliasName,'boa-amex')].{Alias:AliasName,KeyId:TargetKeyId}\" --output table --profile security-tooling"
  }
}

# -----------------------------------------------------------
# PHASE 2 BUILD STATUS
# Updated as each module is added
# -----------------------------------------------------------
output "phase_2_status" {
  description = "Phase 2 Security Tooling build status"
  value = {
    log_archive   = "COMPLETE — ${module.log_archive.log_archive_bucket_name}"
    guardduty     = "COMPLETE — detector ${module.guardduty.detector_id}"
    config        = "NOT STARTED — module reverted, see modules/config"
    security_hub  = "COMPLETE — ${module.security_hub.security_hub_arn}"
    detective     = "NOT STARTED"
    security_lake = "NOT STARTED"
    wiz           = "NOT STARTED"
    sentinel      = "PENDING — Azure subscription required"
  }
}