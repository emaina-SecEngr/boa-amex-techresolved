# ============================================================
# main.tf — Cross-account audit read-only roles
# Module: audit-account
#
# WHAT THIS FILE DOES:
# Creates IAM roles in each AWS account that trust the
# Audit account (445459853572). OCC examiners assume these
# roles from the Audit account to inspect each account.
#
# PROVIDER ALIASES:
# This module uses multiple provider aliases — one per
# account. The Management environment passes these in
# when calling the module.
#
# ROLE TRUST RELATIONSHIP:
# Each role trusts: arn:aws:iam::445459853572:root
# This means: anyone authenticated in the Audit account
# can assume this role (subject to their own permissions)
#
# ROLE PERMISSIONS:
# SecurityAudit (AWS managed) — read security configurations
# ViewOnlyAccess (AWS managed) — read all resource configs
# Combined: complete read-only visibility, zero write access
# ============================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      configuration_aliases = [
        aws.management,
        aws.security_tooling
      ]
    }
  }
}

# -----------------------------------------------------------
# AUDIT ROLE IN MANAGEMENT ACCOUNT
# Allows OCC examiners to review:
#   SCPs, Organization structure, CloudTrail config
#   IAM policies, Config aggregator, billing data
# -----------------------------------------------------------
resource "aws_iam_role" "audit_readonly_management" {
  count    = var.create_management_audit_role ? 1 : 0
  provider = aws.management

  name                 = var.audit_role_name
  description          = var.audit_role_description
  max_session_duration = var.max_session_duration

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAuditAccountAssumption"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.audit_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "BOA-AMEX-OCC-AUDIT"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.project_prefix}-audit-readonly-management"
    AccountType = "Management"
    Purpose     = "OCC examiner read-only access to Management account"
  })
}

resource "aws_iam_role_policy_attachment" "audit_management_security" {
  count      = var.create_management_audit_role ? 1 : 0
  provider   = aws.management
  role       = aws_iam_role.audit_readonly_management[0].name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "aws_iam_role_policy_attachment" "audit_management_viewonly" {
  count      = var.create_management_audit_role ? 1 : 0
  provider   = aws.management
  role       = aws_iam_role.audit_readonly_management[0].name
  policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
}

# -----------------------------------------------------------
# AUDIT ROLE IN SECURITY TOOLING ACCOUNT
# Allows OCC examiners to review:
#   GuardDuty findings, Security Hub findings
#   CloudTrail logs, Config compliance status
#   Detective graph (behavioral analysis)
#   SOAR Lambda functions and EventBridge rules
# -----------------------------------------------------------
resource "aws_iam_role" "audit_readonly_security_tooling" {
  count    = var.create_security_tooling_audit_role ? 1 : 0
  provider = aws.security_tooling

  name                 = var.audit_role_name
  description          = var.audit_role_description
  max_session_duration = var.max_session_duration

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAuditAccountAssumption"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.audit_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "BOA-AMEX-OCC-AUDIT"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.project_prefix}-audit-readonly-security-tooling"
    AccountType = "SecurityTooling"
    Purpose     = "OCC examiner read-only access to Security Tooling account"
  })
}

resource "aws_iam_role_policy_attachment" "audit_security_tooling_security" {
  count      = var.create_security_tooling_audit_role ? 1 : 0
  provider   = aws.security_tooling
  role       = aws_iam_role.audit_readonly_security_tooling[0].name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "aws_iam_role_policy_attachment" "audit_security_tooling_viewonly" {
  count      = var.create_security_tooling_audit_role ? 1 : 0
  provider   = aws.security_tooling
  role       = aws_iam_role.audit_readonly_security_tooling[0].name
  policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
}

# -----------------------------------------------------------
# AUDIT ACCOUNT TRUST POLICY
# In the Audit account itself — allows OCCExaminer
# Permission Set users to assume roles in other accounts
# -----------------------------------------------------------
resource "aws_iam_policy" "assume_audit_roles" {
  provider = aws.management

  name        = "${var.project_prefix}-assume-audit-roles"
  description = "Allows assuming AuditReadOnly role in all accounts. Attached to OCCExaminer Permission Set boundary."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAssumeAuditRoles"
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = [
          "arn:aws:iam::${var.management_account_id}:role/${var.audit_role_name}",
          "arn:aws:iam::${var.security_tooling_account_id}:role/${var.audit_role_name}",
        ]
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "BOA-AMEX-OCC-AUDIT"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-assume-audit-roles"
    Purpose = "Allows OCCExaminer to pivot from Audit account into all other accounts"
  })
}