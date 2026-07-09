# ============================================================
# entra_groups.tf — Microsoft Entra ID Groups + AWS assignments
# Module: iam-identity-center
#
# WHAT THIS FILE DOES:
# 1. Creates security groups in Entra ID for each AWS role
# 2. Assigns existing Entra ID users to appropriate groups
# 3. SCIM automatically syncs these groups to AWS Identity Center
# 4. Assigns synced groups to Permission Sets in specific accounts
#
# WHY THIS IS NOT MANUAL:
# In production, HR systems trigger group membership automatically
# This Terraform code is the IaC equivalent — group creation
# and membership managed as code, reviewed, version-controlled
#
# PROVIDER REQUIRED:
# azuread provider with Global Administrator permissions
# ============================================================

# -----------------------------------------------------------
# DATA SOURCES — existing Entra ID users
# Reference existing users by their UPN (email)
# These users already exist in your Entra ID directory
# -----------------------------------------------------------
data "azuread_user" "eliud" {
  user_principal_name = "mwangi.maina83_gmail.com#EXT#@mwangimaina83gmail.onmicrosoft.com"
}

# -----------------------------------------------------------
# ENTRA ID GROUPS — one per AWS Permission Set
# Security-enabled groups that SCIM will sync to AWS
# -----------------------------------------------------------
resource "azuread_group" "aws_security_auditors" {
  display_name     = "AWS-SecurityAuditors"
  security_enabled = true
  description      = "Members get SecurityAuditor Permission Set in AWS — read-only access across all accounts. Managed by Terraform."

  members = [
    data.azuread_user.eliud.id
  ]
}

resource "azuread_group" "aws_developers" {
  display_name     = "AWS-Developers"
  security_enabled = true
  description      = "Members get Developer Permission Set in AWS — limited access in NonProd accounts only. Managed by Terraform."

  members = [
    data.azuread_user.eliud.id
  ]
}

resource "azuread_group" "aws_network_admins" {
  display_name     = "AWS-NetworkAdmins"
  security_enabled = true
  description      = "Members get NetworkAdmin Permission Set in AWS — network resource management across all accounts. Managed by Terraform."

  members = [
    data.azuread_user.eliud.id
  ]
}

resource "azuread_group" "aws_break_glass" {
  display_name     = "AWS-BreakGlass"
  security_enabled = true
  description      = "EMERGENCY ONLY. Members get BreakGlass Permission Set — full admin for 1 hour. Every use triggers CISO alert. Restrict to 2-3 people maximum. Managed by Terraform."

  members = [
    data.azuread_user.eliud.id
  ]
}

resource "azuread_group" "aws_occ_examiners" {
  display_name     = "AWS-OCCExaminers"
  security_enabled = true
  description      = "OCC examiners and internal auditors. Members get read-only access across all AWS accounts. Assignment is time-limited — add members only during examination periods. Managed by Terraform."

  members = []
}

# -----------------------------------------------------------
# AWS ACCOUNT ASSIGNMENTS
# Assigns Entra ID groups (after SCIM sync) to Permission Sets
# in specific AWS accounts
#
# IMPORTANT: These resources reference group IDs that must
# exist in AWS Identity Center AFTER SCIM sync completes.
# SCIM sync runs automatically every 40 minutes or on-demand.
#
# We use the azuread_group object_id which SCIM uses as the
# external ID when creating groups in AWS Identity Center.
# Terraform references them via data source after sync.
# -----------------------------------------------------------

# Wait for SCIM to sync — use data source to find synced groups
data "aws_identitystore_group" "security_auditors" {
  identity_store_id = local.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = "AWS-SecurityAuditors"
    }
  }

  depends_on = [azuread_group.aws_security_auditors]
}

data "aws_identitystore_group" "developers" {
  identity_store_id = local.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = "AWS-Developers"
    }
  }

  depends_on = [azuread_group.aws_developers]
}

data "aws_identitystore_group" "break_glass" {
  identity_store_id = local.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = "AWS-BreakGlass"
    }
  }

  depends_on = [azuread_group.aws_break_glass]
}

data "aws_identitystore_group" "occ_examiners" {
  identity_store_id = local.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = "AWS-OCCExaminers"
    }
  }

  depends_on = [azuread_group.aws_occ_examiners]
}

# -----------------------------------------------------------
# PERMISSION SET ASSIGNMENTS — Security Tooling account
# SecurityAuditor + BreakGlass can access Security Tooling
# -----------------------------------------------------------
resource "aws_ssoadmin_account_assignment" "security_auditor_security_tooling" {
  count = var.deploy_identity_center ? 1 : 0

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.security_auditor[0].arn
  principal_id       = data.aws_identitystore_group.security_auditors.group_id
  principal_type     = "GROUP"
  target_id          = var.security_tooling_account_id
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "break_glass_security_tooling" {
  count = var.deploy_identity_center ? 1 : 0

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.break_glass[0].arn
  principal_id       = data.aws_identitystore_group.break_glass.group_id
  principal_type     = "GROUP"
  target_id          = var.security_tooling_account_id
  target_type        = "AWS_ACCOUNT"
}

# -----------------------------------------------------------
# PERMISSION SET ASSIGNMENTS — Management account
# BreakGlass only — no regular access to Management
# -----------------------------------------------------------
resource "aws_ssoadmin_account_assignment" "break_glass_management" {
  count = var.deploy_identity_center ? 1 : 0

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.break_glass[0].arn
  principal_id       = data.aws_identitystore_group.break_glass.group_id
  principal_type     = "GROUP"
  target_id          = var.management_account_id
  target_type        = "AWS_ACCOUNT"
}

# -----------------------------------------------------------
# PERMISSION SET ASSIGNMENTS — Audit account
# OCCExaminer gets access to Audit account
# From Audit account they use cross-account roles elsewhere
# -----------------------------------------------------------
resource "aws_ssoadmin_account_assignment" "occ_examiner_audit" {
  count = var.deploy_identity_center && var.audit_account_id != "" ? 1 : 0

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.occ_examiner[0].arn
  principal_id       = data.aws_identitystore_group.occ_examiners.group_id
  principal_type     = "GROUP"
  target_id          = var.audit_account_id
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "security_auditor_audit" {
  count = var.deploy_identity_center && var.audit_account_id != "" ? 1 : 0

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.security_auditor[0].arn
  principal_id       = data.aws_identitystore_group.security_auditors.group_id
  principal_type     = "GROUP"
  target_id          = var.audit_account_id
  target_type        = "AWS_ACCOUNT"
}