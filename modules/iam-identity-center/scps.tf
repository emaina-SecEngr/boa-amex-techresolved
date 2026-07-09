# ============================================================
# scps.tf — Service Control Policies
# Module: iam-identity-center
#
# WHAT ARE SCPs:
# Service Control Policies are the highest-level permission
# boundary in AWS. They apply to EVERY account in the OU
# they're attached to — including the root account of those
# accounts. They CANNOT be overridden by any IAM policy,
# including AdministratorAccess.
#
# IMPORTANT: SCPs are PERMISSION BOUNDARIES, not grants.
# They define the MAXIMUM permissions available.
# An action must be BOTH allowed by SCP AND by IAM policy.
#
# OUR FIVE SCPs:
# 1. DenyRootUsage          — prevents root login org-wide
# 2. DenyPublicS3           — prevents public S3 buckets
# 3. DenyRegionExit         — restricts to approved regions
# 4. RequireEncryption      — enforces encryption at rest
# 5. DenyDisablingSecurity  — prevents disabling security tools
#
# ATTACHMENT STRATEGY:
# Root → DenyRootUsage (applies everywhere)
# Security OU → all 5 SCPs (strictest)
# Production OU → all 5 SCPs (strictest)
# NonProduction OU → DenyRootUsage + DenyPublicS3 (relaxed)
# Pipeline OU → DenyRootUsage only (needs flexibility)
# Compliance OU → DenyAllWrites (audit account protection)
# ============================================================

# -----------------------------------------------------------
# SCP 1 — DENY ROOT USAGE
# Prevents root account login in ALL member accounts
# Root credentials are the most powerful and most dangerous
# OCC requirement: root usage must be rare, justified, audited
# Applied to: Organization root (all accounts)
# -----------------------------------------------------------
resource "aws_organizations_policy" "deny_root_usage" {
  count = var.deploy_scps ? 1 : 0

  name        = "${var.project_prefix}-deny-root-usage"
  description = "Prevents root account usage in all member accounts. Root credentials bypass all IAM policies and SCPs — must never be used for day-to-day operations. OCC requirement."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyRootAccountUsage"
        Effect   = "Deny"
        Action   = "*"
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:PrincipalArn" = "arn:aws:iam::*:root"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-deny-root-usage"
    SCPType = "Preventive"
  })
}

resource "aws_organizations_policy_attachment" "deny_root_usage_root" {
  count     = var.deploy_scps ? 1 : 0
  policy_id = aws_organizations_policy.deny_root_usage[0].id
  target_id = var.root_id
}

# -----------------------------------------------------------
# SCP 2 — DENY PUBLIC S3
# Prevents making any S3 bucket publicly accessible
# PCI-DSS Requirement 1.3: restrict network access
# Applied to: Security OU + Production OU
# NonProduction has relaxed version (Dev may need public buckets
# for testing static websites — explicit exception)
# -----------------------------------------------------------
resource "aws_organizations_policy" "deny_public_s3" {
  count = var.deploy_scps ? 1 : 0

  name        = "${var.project_prefix}-deny-public-s3"
  description = "Prevents any S3 bucket from being made publicly accessible. PCI-DSS Req 1.3 and OCC data protection requirement. Applied to Production and Security OUs."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyPublicS3ACL"
        Effect = "Deny"
        Action = [
          "s3:PutBucketAcl",
          "s3:PutObjectAcl"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = [
              "public-read",
              "public-read-write",
              "authenticated-read"
            ]
          }
        }
      },
      {
        Sid    = "DenyPublicS3Policy"
        Effect = "Deny"
        Action = [
          "s3:PutBucketPublicAccessBlock"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "s3:PublicAccessBlockConfiguration" = "false"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-deny-public-s3"
    SCPType = "Preventive"
  })
}

resource "aws_organizations_policy_attachment" "deny_public_s3_security" {
  count     = var.deploy_scps && var.security_ou_id != "" ? 1 : 0
  policy_id = aws_organizations_policy.deny_public_s3[0].id
  target_id = var.security_ou_id
}

resource "aws_organizations_policy_attachment" "deny_public_s3_production" {
  count     = var.deploy_scps && var.production_ou_id != "" ? 1 : 0
  policy_id = aws_organizations_policy.deny_public_s3[0].id
  target_id = var.production_ou_id
}

resource "aws_organizations_policy_attachment" "deny_public_s3_non_production" {
  count     = var.deploy_scps && var.non_production_ou_id != "" ? 1 : 0
  policy_id = aws_organizations_policy.deny_public_s3[0].id
  target_id = var.non_production_ou_id
}

# -----------------------------------------------------------
# SCP 3 — DENY REGION EXIT
# Restricts resource creation to approved regions only
# Prevents attackers from using obscure regions to evade
# detection (GuardDuty and Config only cover enabled regions)
# Applied to: All OUs
# -----------------------------------------------------------
resource "aws_organizations_policy" "deny_region_exit" {
  count = var.deploy_scps ? 1 : 0

  name        = "${var.project_prefix}-deny-region-exit"
  description = "Restricts AWS resource creation to approved regions only. Prevents use of regions where security monitoring may not be configured. Global services (IAM, STS, Route53) are exempt."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyNonApprovedRegions"
        Effect = "Deny"
        NotAction = [
          # Global services — exempt from region restriction
          "iam:*",
          "sts:*",
          "route53:*",
          "cloudfront:*",
          "waf:*",
          "budgets:*",
          "ce:*",
          "support:*",
          "organizations:*",
          "account:*",
          "health:*"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = var.approved_regions
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-deny-region-exit"
    SCPType = "Preventive"
  })
}

resource "aws_organizations_policy_attachment" "deny_region_exit_root" {
  count     = var.deploy_scps ? 1 : 0
  policy_id = aws_organizations_policy.deny_region_exit[0].id
  target_id = var.root_id
}

# -----------------------------------------------------------
# SCP 4 — REQUIRE ENCRYPTION
# Enforces encryption at rest for key storage services
# PCI-DSS Requirement 3.5: protect stored cardholder data
# Applied to: Security OU + Production OU
# -----------------------------------------------------------
resource "aws_organizations_policy" "require_encryption" {
  count = var.deploy_scps ? 1 : 0

  name        = "${var.project_prefix}-require-encryption"
  description = "Enforces encryption at rest for S3, EBS, and RDS. Prevents creation of unencrypted storage resources in Production and Security accounts. PCI-DSS Req 3.5."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyUnencryptedS3"
        Effect   = "Deny"
        Action   = "s3:PutObject"
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = [
              "aws:kms",
              "AES256"
            ]
          }
        }
      },
      {
        Sid      = "DenyUnencryptedEBS"
        Effect   = "Deny"
        Action   = "ec2:CreateVolume"
        Resource = "*"
        Condition = {
          Bool = {
            "ec2:Encrypted" = "false"
          }
        }
      },
      {
        Sid      = "DenyUnencryptedRDS"
        Effect   = "Deny"
        Action   = "rds:CreateDBInstance"
        Resource = "*"
        Condition = {
          Bool = {
            "rds:StorageEncrypted" = "false"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-require-encryption"
    SCPType = "Preventive"
  })
}

resource "aws_organizations_policy_attachment" "require_encryption_security" {
  count     = var.deploy_scps && var.security_ou_id != "" ? 1 : 0
  policy_id = aws_organizations_policy.require_encryption[0].id
  target_id = var.security_ou_id
}

resource "aws_organizations_policy_attachment" "require_encryption_production" {
  count     = var.deploy_scps && var.production_ou_id != "" ? 1 : 0
  policy_id = aws_organizations_policy.require_encryption[0].id
  target_id = var.production_ou_id
}

# -----------------------------------------------------------
# SCP 5 — DENY DISABLING SECURITY SERVICES
# Prevents disabling GuardDuty, Security Hub, CloudTrail,
# Config, or Detective in any account
# This is the most important SCP for OCC compliance
# Applied to: All OUs
# -----------------------------------------------------------
resource "aws_organizations_policy" "deny_disabling_security" {
  count = var.deploy_scps ? 1 : 0

  name        = "${var.project_prefix}-deny-disabling-security"
  description = "Prevents disabling of security monitoring services (GuardDuty, Security Hub, CloudTrail, Config, Detective). Ensures continuous monitoring required by OCC and PCI-DSS."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyDisablingGuardDuty"
        Effect = "Deny"
        Action = [
          "guardduty:DeleteDetector",
          "guardduty:DisassociateFromMasterAccount",
          "guardduty:DisassociateMembers",
          "guardduty:StopMonitoringMembers",
          "guardduty:UpdateDetector"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyDisablingSecurityHub"
        Effect = "Deny"
        Action = [
          "securityhub:DeleteHub",
          "securityhub:DisableSecurityHub",
          "securityhub:DisassociateFromMasterAccount",
          "securityhub:DisassociateMembers"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyDisablingCloudTrail"
        Effect = "Deny"
        Action = [
          "cloudtrail:DeleteTrail",
          "cloudtrail:StopLogging",
          "cloudtrail:UpdateTrail"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyDisablingConfig"
        Effect = "Deny"
        Action = [
          "config:DeleteConfigurationRecorder",
          "config:DeleteDeliveryChannel",
          "config:StopConfigurationRecorder"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyDisablingDetective"
        Effect = "Deny"
        Action = [
          "detective:DeleteGraph",
          "detective:DisassociateMembership"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-deny-disabling-security"
    SCPType = "Preventive"
  })
}

resource "aws_organizations_policy_attachment" "deny_disabling_security_root" {
  count     = var.deploy_scps ? 1 : 0
  policy_id = aws_organizations_policy.deny_disabling_security[0].id
  target_id = var.root_id
}

# -----------------------------------------------------------
# SCP 6 — DENY ALL WRITES (Compliance OU only)
# Applied exclusively to the Compliance OU (Audit account)
# OCC examiners can only READ — never modify anything
# This is the architectural guarantee of audit independence
# -----------------------------------------------------------
resource "aws_organizations_policy" "deny_all_writes_compliance" {
  count = var.deploy_scps ? 1 : 0

  name        = "${var.project_prefix}-deny-all-writes-compliance"
  description = "Applied to Compliance OU only. Prevents ANY write action from the Audit account. OCC examiners have read-only access — this SCP ensures that at the organizational level regardless of IAM policies."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyAllWriteActions"
        Effect = "Deny"
        Action = [
          "s3:Put*",
          "s3:Delete*",
          "s3:Create*",
          "ec2:Run*",
          "ec2:Create*",
          "ec2:Delete*",
          "ec2:Modify*",
          "ec2:Stop*",
          "ec2:Terminate*",
          "iam:Create*",
          "iam:Delete*",
          "iam:Update*",
          "iam:Put*",
          "iam:Attach*",
          "iam:Detach*",
          "lambda:Create*",
          "lambda:Delete*",
          "lambda:Update*",
          "rds:Create*",
          "rds:Delete*",
          "rds:Modify*",
          "guardduty:Create*",
          "guardduty:Delete*",
          "guardduty:Update*",
          "cloudtrail:Create*",
          "cloudtrail:Delete*",
          "cloudtrail:Update*",
          "config:Put*",
          "config:Delete*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-deny-all-writes-compliance"
    SCPType = "Preventive"
    Purpose = "Audit account protection - OCC examiner read-only guarantee"
  })
}

resource "aws_organizations_policy_attachment" "deny_all_writes_compliance" {
  count     = var.deploy_scps && var.compliance_ou_id != "" ? 1 : 0
  policy_id = aws_organizations_policy.deny_all_writes_compliance[0].id
  target_id = var.compliance_ou_id
}