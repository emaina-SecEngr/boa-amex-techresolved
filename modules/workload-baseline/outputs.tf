# ============================================================
# outputs.tf — Exported values from workload-baseline module
# These outputs are consumed by workload-specific modules
# (pci-cde, dev-environment, pipeline) that build on top
# of this baseline
# ============================================================

# -----------------------------------------------------------
# VPC
# -----------------------------------------------------------
output "vpc_id" {
  description = "Workload VPC ID — LBB Scheduler deployed here"
  value       = aws_vpc.workload.id
}

output "vpc_cidr" {
  description = "Workload VPC CIDR block"
  value       = aws_vpc.workload.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs — ALB for LBB frontend"
  value       = var.enable_public_subnets ? aws_subnet.public[*].id : []
}

output "private_subnet_ids" {
  description = "Private subnet IDs — LBB FastAPI backend (ECS/EC2)"
  value       = aws_subnet.private[*].id
}

output "isolated_subnet_ids" {
  description = "Isolated subnet IDs — LBB PostgreSQL RDS (zero internet)"
  value       = aws_subnet.isolated[*].id
}

# -----------------------------------------------------------
# SECURITY GROUPS
# -----------------------------------------------------------
output "alb_security_group_id" {
  description = "ALB Security Group ID — attach to LBB load balancer"
  value       = var.enable_public_subnets ? aws_security_group.alb[0].id : ""
}

output "app_security_group_id" {
  description = "Application Security Group ID — attach to LBB backend containers/instances"
  value       = aws_security_group.app.id
}

output "db_security_group_id" {
  description = "Database Security Group ID — attach to LBB PostgreSQL RDS"
  value       = aws_security_group.db.id
}

# -----------------------------------------------------------
# ENCRYPTION
# -----------------------------------------------------------
output "kms_key_arn" {
  description = "Workload KMS key ARN — encrypts LBB data at rest"
  value       = var.create_workload_kms_key ? aws_kms_key.workload[0].arn : ""
}

output "kms_key_id" {
  description = "Workload KMS key ID"
  value       = var.create_workload_kms_key ? aws_kms_key.workload[0].key_id : ""
}

output "kms_alias" {
  description = "Workload KMS alias"
  value       = var.create_workload_kms_key ? aws_kms_alias.workload[0].name : ""
}

# -----------------------------------------------------------
# SECRETS
# -----------------------------------------------------------
output "lbb_db_password_secret_arn" {
  description = "Secrets Manager ARN for LBB database password"
  value       = var.enable_secrets_manager && var.enable_lbb_scheduler ? aws_secretsmanager_secret.lbb_db_password[0].arn : ""
}

output "lbb_jwt_secret_arn" {
  description = "Secrets Manager ARN for LBB JWT signing key"
  value       = var.enable_secrets_manager && var.enable_lbb_scheduler ? aws_secretsmanager_secret.lbb_jwt_secret[0].arn : ""
}

output "lbb_api_key_secret_arn" {
  description = "Secrets Manager ARN for LBB external API key"
  value       = var.enable_secrets_manager && var.enable_lbb_scheduler ? aws_secretsmanager_secret.lbb_api_key[0].arn : ""
}

# -----------------------------------------------------------
# SECURITY TOOLS
# -----------------------------------------------------------
output "wiz_scanner_role_arn" {
  description = "WizScanner role ARN in this account"
  value       = var.enable_wiz_scanning ? aws_iam_role.wiz_scanner[0].arn : ""
}

output "access_analyzer_arn" {
  description = "IAM Access Analyzer ARN"
  value       = var.enable_iam_access_analyzer ? aws_accessanalyzer_analyzer.workload[0].arn : ""
}

output "permission_boundary_arn" {
  description = "Permission Boundary policy ARN — attach to all developer-created roles"
  value       = var.enable_permission_boundaries && var.permission_boundary_policy_arn == "" ? aws_iam_policy.permission_boundary[0].arn : var.permission_boundary_policy_arn
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN — associate with LBB ALB or API Gateway"
  value       = var.enable_waf ? aws_wafv2_web_acl.lbb[0].arn : ""
}

# -----------------------------------------------------------
# NETWORKING
# -----------------------------------------------------------
output "tgw_attachment_id" {
  description = "Transit Gateway attachment ID — used by Security VPC for route propagation"
  value       = var.enable_transit_gateway && var.transit_gateway_id != "" ? aws_ec2_transit_gateway_vpc_attachment.workload[0].id : ""
}

output "sns_topic_arn" {
  description = "Security alerts SNS topic ARN for this account"
  value       = aws_sns_topic.security_alerts.arn
}

# -----------------------------------------------------------
# STATUS
# -----------------------------------------------------------
output "workload_baseline_status" {
  description = "Complete workload baseline configuration summary"
  value = {
    account_name        = var.account_name
    environment         = var.environment
    data_classification = var.data_classification
    security_preset     = var.security_preset
    vpc_cidr            = var.vpc_cidr
    workload            = "LBB Scheduler"

    network = {
      public_subnets   = var.enable_public_subnets ? "ENABLED (ALB)" : "DISABLED (no internet)"
      private_subnets  = "ENABLED (LBB app tier)"
      isolated_subnets = "ENABLED (LBB database tier)"
      internet_gateway = var.enable_internet_gateway ? "ENABLED" : "DISABLED"
      nat_gateway      = var.enable_nat_gateway ? "ENABLED" : "DISABLED"
      transit_gateway  = var.enable_transit_gateway ? "ATTACHED" : "NOT ATTACHED"
      vpc_endpoints    = var.enable_vpc_endpoints ? "ENABLED (${length(var.vpc_endpoint_services)} services)" : "DISABLED"
      flow_logs        = var.enable_flow_logs ? "ENABLED" : "DISABLED"
    }

    hardening = {
      imdsv2_enforced     = var.enforce_imdsv2 ? "ENFORCED (SSRF prevention)" : "NOT ENFORCED"
      ebs_encryption      = var.enable_ebs_encryption ? "ENABLED (default)" : "DISABLED"
      s3_block_public     = var.enable_s3_block_public ? "ENABLED (account-level)" : "DISABLED"
      kms_key             = var.create_workload_kms_key ? "CREATED" : "USING AWS MANAGED"
      permission_boundary = var.enable_permission_boundaries ? "ENFORCED" : "NOT ENFORCED"
    }

    detection = {
      guardduty       = var.enable_guardduty ? "ENABLED" : "DISABLED"
      security_hub    = var.enable_security_hub ? "ENABLED" : "DISABLED"
      detective       = var.enable_detective ? "ENABLED" : "DISABLED"
      inspector       = var.enable_inspector ? "ENABLED" : "DISABLED"
      access_analyzer = var.enable_iam_access_analyzer ? "ENABLED" : "DISABLED"
      security_lake   = var.enable_security_lake ? "ENABLED" : "DISABLED"
    }

    data_protection = {
      secrets_manager = var.enable_secrets_manager ? "ENABLED" : "DISABLED"
      macie           = var.enable_macie ? "ENABLED" : "DISABLED"
      cloudhsm        = var.enable_cloudhsm ? "ENABLED (${var.cloudhsm_cluster_size} HSMs)" : "DISABLED"
      acm_private_ca  = var.enable_acm_private_ca ? "ENABLED" : "DISABLED"
      nitro_enclaves  = var.enable_nitro_enclaves ? "ENABLED" : "DISABLED"
      dlp             = var.enable_dlp ? "ENABLED" : "DISABLED"
    }

    network_security = {
      waf                     = var.enable_waf ? "ENABLED (${length(var.waf_managed_rules)} rule groups)" : "DISABLED"
      shield_advanced         = var.enable_shield_advanced ? "ENABLED" : "DISABLED"
      firewall_manager        = var.enable_firewall_manager ? "ENABLED" : "DISABLED"
      network_access_analyzer = var.enable_network_access_analyzer ? "ENABLED" : "DISABLED"
      verified_access         = var.enable_verified_access ? "ENABLED" : "DISABLED"
    }

    third_party = {
      wiz         = var.enable_wiz_scanning ? "ENABLED (CSPM/CWPP/CIEM)" : "DISABLED"
      crowdstrike = var.enable_crowdstrike_sensor ? "ENABLED (Falcon EDR)" : "DISABLED"
      sentinel    = var.enable_sentinel_connector ? "ENABLED" : "DISABLED"
    }

    application = {
      cognito       = var.enable_cognito ? "ENABLED" : "DISABLED"
      api_gateway   = var.enable_api_gateway ? "ENABLED" : "DISABLED"
      ecr           = var.enable_ecr ? "ENABLED" : "DISABLED"
      eks           = var.enable_eks ? "ENABLED" : "DISABLED"
      lbb_scheduler = var.enable_lbb_scheduler ? "ENABLED" : "DISABLED"
    }

    governance = {
      budgets         = var.enable_budgets ? "ENABLED ($${var.monthly_budget_amount}/month)" : "DISABLED"
      audit_manager   = var.enable_audit_manager ? "ENABLED" : "DISABLED"
      service_catalog = var.enable_service_catalog ? "ENABLED" : "DISABLED"
      cloudtrail      = var.enable_cloudtrail ? "ENABLED" : "DISABLED"
      cloudtrail_lake = var.enable_cloudtrail_lake ? "ENABLED" : "DISABLED"
    }
  }
}

output "security_services_count" {
  description = "Number of security services enabled in this account"
  value = (
    (var.enable_guardduty ? 1 : 0) +
    (var.enable_detective ? 1 : 0) +
    (var.enable_security_hub ? 1 : 0) +
    (var.enable_security_lake ? 1 : 0) +
    (var.enable_config ? 1 : 0) +
    (var.enable_inspector ? 1 : 0) +
    (var.enable_iam_access_analyzer ? 1 : 0) +
    (var.enable_macie ? 1 : 0) +
    (var.enable_waf ? 1 : 0) +
    (var.enable_secrets_manager ? 1 : 0) +
    (var.enable_wiz_scanning ? 1 : 0) +
    (var.enable_crowdstrike_sensor ? 1 : 0) +
    (var.enable_flow_logs ? 1 : 0) +
    (var.enable_cloudtrail ? 1 : 0) +
    (var.enable_budgets ? 1 : 0) +
    (var.enable_audit_manager ? 1 : 0) +
    (var.enable_patch_manager ? 1 : 0) +
    (var.enable_cloudhsm ? 1 : 0) +
    (var.enable_acm_private_ca ? 1 : 0) +
    (var.enable_sentinel_connector ? 1 : 0)
  )
}

output "occ_evidence_note" {
  description = "OCC examination evidence this module provides"
  value       = "Satisfies: OCC consistent controls requirement - identical security baseline across all workload accounts. Covers PCI-DSS Requirements 1 (network), 2 (config), 3 (encryption), 5 (malware), 7 (access), 8 (auth), 10 (logging), 11 (testing). ${var.enable_lbb_scheduler ? "LBB Scheduler" : "Workload"} protected by ${var.security_preset} security preset with automated compliance monitoring."
}

output "preset_guide" {
  description = "Security preset reference for different workload types"
  value       = <<-EOT
    Security Presets for LBB Scheduler deployments:

    minimal (sandbox):
      LBB dev testing - GuardDuty + Config + CloudTrail
      Cost: ~$5/month

    standard (dev):
      LBB development - adds Security Hub + Inspector + Secrets Manager
      Cost: ~$15/month

    enhanced (production):
      LBB production - adds Wiz + CrowdStrike + WAF + Macie
      Cost: ~$100-200/month + licenses

    pci-cde (card processing):
      LBB processing payments - adds CloudHSM + Nitro Enclaves
      No internet gateway - PrivateLink only
      Cost: ~$2,500-5,000/month + licenses

    maximum (regulated production):
      ALL security tools enabled
      Cost: ~$5,000-10,000/month + licenses
  EOT
}