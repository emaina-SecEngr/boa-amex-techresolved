# ============================================================
# outputs.tf — Exported values from config module
# ============================================================

output "recorder_name" {
  description = "AWS Config configuration recorder name"
  value       = aws_config_configuration_recorder.main.name
}

output "recorder_role_arn" {
  description = "IAM role ARN used by the Config recorder"
  value       = aws_iam_role.config.arn
}

output "delivery_channel_name" {
  description = "AWS Config delivery channel name"
  value       = aws_config_delivery_channel.main.name
}

output "config_status" {
  description = "Summary of Config recorder configuration"
  value = {
    enabled               = var.enable_config ? "ENABLED" : "DISABLED"
    recording_frequency   = var.recording_frequency
    recorded_type_count   = length(var.recorded_resource_types)
    delivery_bucket       = var.log_archive_bucket_name
    aggregator_authorized = var.enable_aggregator_authorization ? "YES — Management account can pull this account's data" : "NO"
  }
}

output "verify_recorder_command" {
  description = "Verify the Config recorder is running and recording"
  value       = "aws configservice describe-configuration-recorder-status --configuration-recorder-names ${aws_config_configuration_recorder.main.name}"
}

output "verify_recorded_resources_command" {
  description = "List which resource types are actually being recorded"
  value       = "aws configservice describe-configuration-recorders --query 'ConfigurationRecorders[0].recordingGroup'"
}

output "occ_evidence_note" {
  description = "OCC examination evidence this module provides"
  value       = "Satisfies: OCC continuous monitoring requirement (Config recorder running, feeding Security Hub compliance standards), PCI-DSS Req 11.5 (change detection), backing evidence for CIS/PCI-DSS/NIST/AWS-Foundational Security Hub standards"
}
