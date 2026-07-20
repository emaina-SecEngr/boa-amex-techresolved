# ============================================================
# outputs.tf — Exported values from aws-organization module
# ============================================================

output "organization_id" {
  description = "AWS Organization ID (r-xxxx) — referenced by all other modules"
  value       = aws_organizations_organization.main.id
}

output "organization_arn" {
  description = "AWS Organization ARN"
  value       = aws_organizations_organization.main.arn
}

output "root_id" {
  description = "Organization root ID — used to attach org-wide SCPs"
  value       = aws_organizations_organization.main.roots[0].id
}

output "master_account_id" {
  description = "Management account ID confirmed by Organization"
  value       = aws_organizations_organization.main.master_account_id
}

# -----------------------------------------------------------
# OU IDs — referenced by modules placing accounts into OUs
# -----------------------------------------------------------
output "security_ou_id" {
  description = "Security OU ID — Security Tooling and Log Archive accounts placed here"
  value       = var.create_security_ou ? aws_organizations_organizational_unit.security[0].id : ""
}

output "production_ou_id" {
  description = "Production OU ID — PCI-CDE and Core Banking accounts placed here"
  value       = var.create_production_ou ? aws_organizations_organizational_unit.production[0].id : ""
}

output "non_production_ou_id" {
  description = "Non-Production OU ID — Dev and QA accounts placed here"
  value       = var.create_non_production_ou ? aws_organizations_organizational_unit.non_production[0].id : ""
}

output "pipeline_ou_id" {
  description = "Pipeline OU ID — CI-CD accounts placed here"
  value       = var.create_pipeline_ou ? aws_organizations_organizational_unit.pipeline[0].id : ""
}

output "compliance_ou_id" {
  description = "Compliance OU ID — Audit account placed here"
  value       = var.create_compliance_ou ? aws_organizations_organizational_unit.compliance[0].id : ""
}

# -----------------------------------------------------------
# ACCOUNT IDs — referenced by cross-account role modules
# -----------------------------------------------------------
output "audit_account_id" {
  description = "Audit account ID — used by audit-account module to create cross-account roles"
  value       = var.create_audit_account ? aws_organizations_account.audit[0].id : ""
}

output "pci_cde_account_id" {
  description = "PCI-CDE account ID — used by workload modules"
  value       = var.create_pci_cde_account ? aws_organizations_account.pci_cde[0].id : ""
}

output "core_banking_account_id" {
  description = "Core Banking account ID"
  value       = var.create_core_banking_account ? aws_organizations_account.core_banking[0].id : ""
}

output "dev_account_id" {
  description = "Dev account ID"
  value       = var.create_dev_account ? aws_organizations_account.dev[0].id : ""
}

output "pipeline_account_id" {
  description = "Pipeline/CI-CD account ID"
  value       = var.create_pipeline_account ? aws_organizations_account.pipeline[0].id : ""
}

output "fraud_detection_account_id" {
  description = "Fraud Detection account ID"
  value       = var.create_fraud_detection_account ? aws_organizations_account.fraud_detection[0].id : ""
}

output "customer_portal_account_id" {
  description = "Customer Portal account ID"
  value       = var.create_customer_portal_account ? aws_organizations_account.customer_portal[0].id : ""
}

output "data_analytics_account_id" {
  description = "Data Analytics account ID"
  value       = var.create_data_analytics_account ? aws_organizations_account.data_analytics[0].id : ""
}

output "bi_reporting_account_id" {
  description = "BI Reporting account ID"
  value       = var.create_bi_reporting_account ? aws_organizations_account.bi_reporting[0].id : ""
}

# -----------------------------------------------------------
# DELEGATED ADMINISTRATOR STATUS
# -----------------------------------------------------------
output "delegated_admin_status" {
  description = "Summary of delegated administrator configuration"
  value = {
    guardduty   = var.enable_guardduty_delegated_admin ? "DELEGATED → ${var.security_tooling_account_id}" : "NOT DELEGATED — enable_guardduty_delegated_admin = false"
    securityhub = var.enable_securityhub_delegated_admin ? "DELEGATED → ${var.security_tooling_account_id}" : "NOT DELEGATED — enable_securityhub_delegated_admin = false"
    detective   = var.enable_detective_delegated_admin ? "DELEGATED → ${var.security_tooling_account_id}" : "NOT DELEGATED — enable_detective_delegated_admin = false"
    config      = var.enable_config_delegated_admin ? "DELEGATED → ${var.security_tooling_account_id}" : "NOT DELEGATED — enable_config_delegated_admin = false"
  }
}

# -----------------------------------------------------------
# VERIFICATION COMMANDS
# Run these after terraform apply to confirm correct state
# -----------------------------------------------------------
output "verify_organization_command" {
  description = "Verify Organization structure and enabled services"
  value       = "aws organizations describe-organization --query 'Organization.{Id:Id,FeatureSet:FeatureSet,MasterAccountId:MasterAccountId}' --output table"
}

output "verify_ous_command" {
  description = "List all OUs under the root"
  value       = "aws organizations list-organizational-units-for-parent --parent-id ${aws_organizations_organization.main.roots[0].id} --query 'OrganizationalUnits[].{Name:Name,Id:Id}' --output table"
}

output "verify_accounts_command" {
  description = "List all accounts in the Organization"
  value       = "aws organizations list-accounts --query 'Accounts[].{Name:Name,Id:Id,Status:Status,Email:Email}' --output table"
}

output "verify_delegated_admins_command" {
  description = "List all delegated administrators configured"
  value       = "aws organizations list-delegated-administrators --query 'DelegatedAdministrators[].{AccountId:Id,Services:DelegationEnabledDate}' --output table"
}

output "import_commands" {
  description = "Terraform import commands needed for existing resources"
  value       = <<-EOT
    # Run these BEFORE terraform apply to import existing resources:
    terraform import module.aws_organization.aws_organizations_organization.main r-iaiz
    terraform import module.aws_organization.aws_organizations_account.security_tooling 368351959735
  EOT
}