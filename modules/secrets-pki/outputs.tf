output "secrets_kms_key_arn" {
  description = "KMS key ARN for Secrets Manager encryption"
  value       = var.enable_secrets_management ? aws_kms_key.secrets[0].arn : ""
}

output "secret_rotator_arn" {
  description = "Secret rotation Lambda ARN"
  value       = var.enable_secrets_management ? aws_lambda_function.secret_rotator[0].arn : ""
}

output "private_ca_arn" {
  description = "ACM Private CA ARN for internal mTLS"
  value       = var.enable_private_ca ? aws_acmpca_certificate_authority.internal[0].arn : ""
}

output "secrets_status" {
  description = "Secrets and PKI module configuration summary"
  value = {
    secrets_management = var.enable_secrets_management ? "ENABLED" : "DISABLED"
    private_ca         = var.enable_private_ca ? "ENABLED — mTLS for inter-service auth" : "DISABLED"
    database_secrets   = var.enable_secrets_management ? length(var.database_secrets) : 0
    api_secrets        = var.enable_secrets_management ? length(var.api_secrets) : 0
    rotation_interval  = "${var.secret_rotation_days} days"
    workload_accounts  = length(var.workload_account_ids)
  }
}

output "occ_evidence_note" {
  description = "OCC and PCI-DSS evidence from secrets-pki module"
  value       = "Satisfies: PCI-DSS Req 2.3 (encrypt admin access), Req 4.1 (strong cryptography in transit via mTLS), Req 8.2.4 (credential rotation every 90 days), Req 3.5 (protect cryptographic keys). All secrets centralized in Secrets Manager with KMS encryption, automatic rotation, cross-account resource policies, and CloudTrail audit trail. Private CA enables mutual TLS between all banking microservices."
}