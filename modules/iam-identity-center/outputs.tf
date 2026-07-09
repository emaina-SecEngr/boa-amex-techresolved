# ============================================================
# outputs.tf — Exported values from iam-identity-center module
# ============================================================

output "permission_set_arns" {
  description = "ARNs of the five deployed Permission Sets"
  value = var.deploy_identity_center ? {
    security_auditor = aws_ssoadmin_permission_set.security_auditor[0].arn
    developer        = aws_ssoadmin_permission_set.developer[0].arn
    network_admin    = aws_ssoadmin_permission_set.network_admin[0].arn
    break_glass      = aws_ssoadmin_permission_set.break_glass[0].arn
    occ_examiner     = aws_ssoadmin_permission_set.occ_examiner[0].arn
  } : {}
}

output "scp_ids" {
  description = "IDs of the six deployed Service Control Policies"
  value = var.deploy_scps ? {
    deny_root_usage            = aws_organizations_policy.deny_root_usage[0].id
    deny_public_s3             = aws_organizations_policy.deny_public_s3[0].id
    deny_region_exit           = aws_organizations_policy.deny_region_exit[0].id
    require_encryption         = aws_organizations_policy.require_encryption[0].id
    deny_disabling_security    = aws_organizations_policy.deny_disabling_security[0].id
    deny_all_writes_compliance = aws_organizations_policy.deny_all_writes_compliance[0].id
  } : {}
}

output "sso_portal_url" {
  description = "AWS access portal URL. The Identity Center subdomain is chosen once via the console and cannot be set via Terraform — retrieve it from IAM Identity Center > Settings > AWS access portal URL."
  value       = "Retrieve from AWS Console: IAM Identity Center > Settings > AWS access portal URL"
}

output "next_steps" {
  description = "Remaining manual configuration steps"
  value       = var.deploy_entra_id_connection ? "Entra ID SAML connection deployed via Terraform. Verify SCIM provisioning and assign Entra ID groups to Permission Sets in the AWS access portal." : "Entra ID SAML + SCIM must be configured manually (see docs/entra-id-integration.md). After that: assign Entra ID groups to each Permission Set for the target accounts/OUs."
}
