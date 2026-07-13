# ============================================================
# main.tf — Wiz CNAPP cross-account scanner roles
# Module: wiz
#
# DEPLOYMENT ACCOUNT: Security Tooling (368351959735)
# PREREQUISITE: All other Phase 2 modules complete
#
# NOTE: This module creates the AWS-side infrastructure
# (IAM roles, KMS grants) that ALLOWS Wiz to scan.
# The Wiz console configuration (connector setup,
# scan policies, alert routing) is done in Wiz UI
# after these roles are created.
# ============================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

# -----------------------------------------------------------
# WIZ SCANNER IAM ROLE
# This is the role Wiz assumes to scan your account
# Trust policy allows only Wiz's AWS account to assume it
# ExternalId prevents confused deputy attacks
# -----------------------------------------------------------
resource "aws_iam_role" "wiz_scanner" {
  count = var.enable_wiz_scanner ? 1 : 0
  name  = "WizScanner"

  description = "Cross-account role for Wiz CNAPP agentless scanning. Assumed by Wiz AWS account for CSPM, CWPP, CIEM, and data scanning."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowWizScanning"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.wiz_aws_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.wiz_external_id != "" ? var.wiz_external_id : "WIZ-BOA-AMEX-SCANNER"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "WizScanner"
    Purpose = "Wiz CNAPP agentless scanning - CSPM CWPP CIEM"
  })
}

# -----------------------------------------------------------
# CSPM PERMISSIONS
# Read all resource configurations for misconfiguration detection
# SecurityAudit covers most services
# Additional policies for comprehensive coverage
# -----------------------------------------------------------
resource "aws_iam_role_policy_attachment" "wiz_security_audit" {
  count      = var.enable_wiz_scanner && var.enable_cspm_scanning ? 1 : 0
  role       = aws_iam_role.wiz_scanner[0].name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "aws_iam_role_policy_attachment" "wiz_readonly" {
  count      = var.enable_wiz_scanner && var.enable_cspm_scanning ? 1 : 0
  role       = aws_iam_role.wiz_scanner[0].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# -----------------------------------------------------------
# CWPP PERMISSIONS
# Create and read EBS snapshots for vulnerability scanning
# Wiz creates snapshot → mounts in own account → scans → deletes
# -----------------------------------------------------------
resource "aws_iam_role_policy" "wiz_cwpp" {
  count = var.enable_wiz_scanner && var.enable_cwpp_scanning ? 1 : 0
  name  = "WizCWPPScanning"
  role  = aws_iam_role.wiz_scanner[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "WizEBSSnapshotScanning"
        Effect = "Allow"
        Action = [
          "ec2:CreateSnapshot",
          "ec2:CreateSnapshots",
          "ec2:DescribeSnapshots",
          "ec2:DescribeSnapshotAttribute",
          "ec2:ModifySnapshotAttribute",
          "ec2:DeleteSnapshot",
          "ec2:DescribeVolumes",
          "ec2:DescribeInstances",
          "ec2:DescribeImages",
          "ec2:CopySnapshot"
        ]
        Resource = "*"
      },
      {
        Sid    = "WizLambdaCodeScanning"
        Effect = "Allow"
        Action = [
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:ListFunctions",
          "lambda:GetLayerVersion"
        ]
        Resource = "*"
      },
      {
        Sid    = "WizContainerScanning"
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeImages",
          "ecr:ListImages",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------
# CIEM PERMISSIONS
# Analyze IAM policies for excessive permissions
# and toxic combinations
# -----------------------------------------------------------
resource "aws_iam_role_policy" "wiz_ciem" {
  count = var.enable_wiz_scanner && var.enable_ciem_scanning ? 1 : 0
  name  = "WizCIEMScanning"
  role  = aws_iam_role.wiz_scanner[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "WizIAMAnalysis"
        Effect = "Allow"
        Action = [
          "iam:GetAccountAuthorizationDetails",
          "iam:ListAttachedRolePolicies",
          "iam:ListAttachedUserPolicies",
          "iam:ListAttachedGroupPolicies",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
          "iam:ListEntitiesForPolicy",
          "iam:GetRole",
          "iam:ListRoles",
          "iam:ListUsers",
          "iam:ListGroups",
          "iam:GetUser",
          "iam:ListAccessKeys",
          "iam:ListUserPolicies",
          "iam:GetUserPolicy",
          "iam:ListRolePolicies",
          "iam:GetRolePolicy",
          "iam:ListInstanceProfiles",
          "iam:GetInstanceProfile",
          "iam:GenerateServiceLastAccessedDetails",
          "iam:GetServiceLastAccessedDetails"
        ]
        Resource = "*"
      },
      {
        Sid    = "WizOrganizationsAnalysis"
        Effect = "Allow"
        Action = [
          "organizations:DescribeOrganization",
          "organizations:ListAccounts",
          "organizations:ListPolicies",
          "organizations:DescribePolicy"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------
# DATA SCANNING PERMISSIONS
# Scan S3 objects for PII, PAN, secrets
# Required for PCI-DSS data classification
# -----------------------------------------------------------
resource "aws_iam_role_policy" "wiz_data_scanning" {
  count = var.enable_wiz_scanner && var.enable_data_scanning ? 1 : 0
  name  = "WizDataScanning"
  role  = aws_iam_role.wiz_scanner[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "WizS3DataScanning"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketPolicy",
          "s3:GetBucketAcl",
          "s3:GetEncryptionConfiguration"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalOrgID" = var.organization_id
          }
        }
      },
      {
        Sid    = "WizSecretsDetection"
        Effect = "Allow"
        Action = [
          "secretsmanager:ListSecrets",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------
# KMS GRANT
# Allows Wiz to decrypt KMS-encrypted EBS snapshots
# Without this Wiz cannot scan encrypted volumes
# -----------------------------------------------------------
resource "aws_kms_grant" "wiz_scanner" {
  count             = var.enable_wiz_scanner && var.enable_kms_grants && var.log_archive_kms_key_arn != "" ? 1 : 0
  name              = "${var.project_prefix}-wiz-scanner-grant"
  key_id            = var.log_archive_kms_key_arn
  grantee_principal = aws_iam_role.wiz_scanner[0].arn

  operations = [
    "Decrypt",
    "DescribeKey",
    "GenerateDataKey",
    "GenerateDataKeyWithoutPlaintext",
    "ReEncryptFrom",
    "ReEncryptTo",
    "CreateGrant"
  ]
}

# -----------------------------------------------------------
# FINDINGS WEBHOOK — routes Wiz findings to Security Lake
# API Gateway endpoint that receives Wiz webhook calls
# Lambda function normalizes to OCSF and sends to Security Lake
# Toggled off until Wiz trial is active
# -----------------------------------------------------------
resource "aws_sns_topic" "wiz_findings" {
  count = var.enable_wiz_scanner ? 1 : 0
  name  = "${var.project_prefix}-wiz-findings"

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-wiz-findings"
    Purpose = "Wiz CNAPP critical finding alerts"
  })
}

resource "aws_sns_topic_subscription" "wiz_findings_email" {
  count     = var.enable_wiz_scanner ? 1 : 0
  topic_arn = aws_sns_topic.wiz_findings[0].arn
  protocol  = "email"
  endpoint  = var.security_alert_email
}

# EventBridge rule for Wiz findings via Security Hub
resource "aws_cloudwatch_event_rule" "wiz_critical" {
  count       = var.enable_wiz_scanner ? 1 : 0
  name        = "${var.project_prefix}-wiz-critical-finding"
  description = "Captures critical Wiz findings forwarded via Security Hub"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        ProductName = [{ wildcard = "*Wiz*" }]
        Severity = {
          Label = ["CRITICAL", "HIGH"]
        }
      }
    }
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_prefix}-wiz-critical-finding"
  })
}

resource "aws_cloudwatch_event_target" "wiz_sns" {
  count     = var.enable_wiz_scanner ? 1 : 0
  rule      = aws_cloudwatch_event_rule.wiz_critical[0].name
  target_id = "WizSNS"
  arn       = aws_sns_topic.wiz_findings[0].arn
}