# ============================================================
# outputs.tf — Exported values from audit-account module
# ============================================================

output "audit_role_arn_management" {
  description = "ARN of the AuditReadOnly role in Management account"
  value       = var.create_management_audit_role ? aws_iam_role.audit_readonly_management[0].arn : ""
}

output "audit_role_arn_security_tooling" {
  description = "ARN of the AuditReadOnly role in Security Tooling account"
  value       = var.create_security_tooling_audit_role ? aws_iam_role.audit_readonly_security_tooling[0].arn : ""
}

output "audit_role_name" {
  description = "Name of the cross-account audit role (same in all accounts)"
  value       = var.audit_role_name
}

output "assume_role_commands" {
  description = "AWS CLI commands for OCC examiners to assume audit roles"
  value = {
    management       = "aws sts assume-role --role-arn arn:aws:iam::${var.management_account_id}:role/${var.audit_role_name} --role-session-name OCC-Examination --external-id BOA-AMEX-OCC-AUDIT"
    security_tooling = "aws sts assume-role --role-arn arn:aws:iam::${var.security_tooling_account_id}:role/${var.audit_role_name} --role-session-name OCC-Examination --external-id BOA-AMEX-OCC-AUDIT"
  }
}

output "occ_examination_guide" {
  description = "How OCC examiners access each account"
  value       = <<-EOT
    OCC Examiner Access Flow:
    1. Log into SSO portal: https://ssoins-72238d4e4906358a.portal.us-east-1.app.aws
    2. Select Amex-Audit account → OCCExaminer Permission Set
    3. From Audit account, assume AuditReadOnly role in target account:
       aws sts assume-role \
         --role-arn arn:aws:iam::ACCOUNT_ID:role/AuditReadOnly \
         --role-session-name OCC-Examination \
         --external-id BOA-AMEX-OCC-AUDIT
    4. Use returned credentials to access target account read-only
    5. All actions logged in CloudTrail in both Audit and target accounts
  EOT
}

output "verify_audit_roles_command" {
  description = "Verify AuditReadOnly roles exist in all accounts"
  value       = "aws iam get-role --role-name ${var.audit_role_name} --query 'Role.{Name:RoleName,Arn:Arn,MaxSession:MaxSessionDuration}' --output table"
}