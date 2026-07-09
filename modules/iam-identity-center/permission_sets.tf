# ============================================================
# permission_sets.tf — IAM Identity Center Permission Sets
# Module: iam-identity-center
#
# WHAT ARE PERMISSION SETS:
# Permission Sets define what AWS permissions a user gets
# when they log in via Identity Center SSO.
# They are like IAM roles, but managed centrally and
# assigned to users/groups from Entra ID.
#
# OUR FIVE PERMISSION SETS:
# 1. SecurityAuditor  — read-only all accounts (security team)
# 2. Developer        — limited access in Dev/NonProd only
# 3. NetworkAdmin     — network resources only
# 4. BreakGlass       — full admin, 1 hour, alarmed
# 5. OCCExaminer      — read-only all accounts (auditors)
#
# HOW THEY WORK WITH ENTRA ID:
# Entra ID Groups → assigned to Permission Sets → access to accounts
# Example:
#   Entra ID Group "AWS-SecurityAuditors"
#   → assigned SecurityAuditor Permission Set
#   → assigned to Security Tooling + PCI-CDE + Core Banking accounts
#   → members see read-only view of those accounts via SSO
# ============================================================

data "aws_ssoadmin_instances" "main" {}

locals {
  sso_instance_arn  = tolist(data.aws_ssoadmin_instances.main.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.main.identity_store_ids)[0]
}

# -----------------------------------------------------------
# PERMISSION SET 1 — SecurityAuditor
# Read-only access across all accounts
# Used by: Internal security team, compliance team
# Session: 8 hours (full work day)
# Accounts: all accounts
# -----------------------------------------------------------
resource "aws_ssoadmin_permission_set" "security_auditor" {
  count = var.deploy_identity_center ? 1 : 0

  name             = "SecurityAuditor"
  description      = "Read-only access across all AWS accounts. Used by security team for continuous monitoring and compliance review. Cannot modify any resource."
  instance_arn     = local.sso_instance_arn
  session_duration = "PT${var.security_auditor_session_hours}H"

  tags = merge(var.common_tags, {
    Name    = "SecurityAuditor"
    Purpose = "Security team read-only access"
  })
}

resource "aws_ssoadmin_managed_policy_attachment" "security_auditor" {
  count = var.deploy_identity_center ? 1 : 0

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.security_auditor[0].arn
  managed_policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "aws_ssoadmin_managed_policy_attachment" "security_auditor_readonly" {
  count = var.deploy_identity_center ? 1 : 0

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.security_auditor[0].arn
  managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# -----------------------------------------------------------
# PERMISSION SET 2 — Developer
# Limited access in NonProduction accounts only
# Used by: Application developers
# Session: 4 hours (re-authenticate mid-day)
# Accounts: Dev + NonProd only (SCPs prevent Production access)
# -----------------------------------------------------------
resource "aws_ssoadmin_permission_set" "developer" {
  count = var.deploy_identity_center ? 1 : 0

  name             = "Developer"
  description      = "Developer access for NonProduction accounts only. Allows EC2, Lambda, S3, RDS operations in Dev/Staging. Cannot access Production accounts."
  instance_arn     = local.sso_instance_arn
  session_duration = "PT${var.developer_session_hours}H"

  tags = merge(var.common_tags, {
    Name    = "Developer"
    Purpose = "Application developer access - NonProd only"
  })
}

resource "aws_ssoadmin_permission_set_inline_policy" "developer" {
  count = var.deploy_identity_center ? 1 : 0

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.developer[0].arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DeveloperComputeAccess"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:RunInstances",
          "ec2:StopInstances",
          "ec2:StartInstances",
          "ec2:TerminateInstances",
          "ec2:CreateTags",
          "lambda:*",
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject",
          "rds:Describe*",
          "rds:ListTagsForResource",
          "cloudwatch:GetMetricData",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricStatistics",
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      },
      {
        Sid      = "DenyProductionAccess"
        Effect   = "Deny"
        Action   = "*"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceAccount" = [
              var.security_tooling_account_id,
              var.management_account_id
            ]
          }
        }
      }
    ]
  })
}

# -----------------------------------------------------------
# PERMISSION SET 3 — NetworkAdmin
# Network resource management only
# Used by: Network engineering team
# Session: 4 hours
# Accounts: all accounts (network spans all)
# -----------------------------------------------------------
resource "aws_ssoadmin_permission_set" "network_admin" {
  count = var.deploy_identity_center ? 1 : 0

  name             = "NetworkAdmin"
  description      = "Network resource management across all accounts. VPC, Transit Gateway, Security Groups, Network Firewall, Route53. Cannot access compute or storage resources."
  instance_arn     = local.sso_instance_arn
  session_duration = "PT${var.network_admin_session_hours}H"

  tags = merge(var.common_tags, {
    Name    = "NetworkAdmin"
    Purpose = "Network team access"
  })
}

resource "aws_ssoadmin_permission_set_inline_policy" "network_admin" {
  count = var.deploy_identity_center ? 1 : 0

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.network_admin[0].arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "NetworkAdminAccess"
        Effect = "Allow"
        Action = [
          "ec2:*Vpc*",
          "ec2:*Subnet*",
          "ec2:*RouteTable*",
          "ec2:*InternetGateway*",
          "ec2:*SecurityGroup*",
          "ec2:*NetworkAcl*",
          "ec2:*TransitGateway*",
          "ec2:*VpnGateway*",
          "ec2:*NatGateway*",
          "ec2:Describe*",
          "ec2:CreateTags",
          "route53:*",
          "route53resolver:*",
          "network-firewall:*",
          "elasticloadbalancing:*",
          "globalaccelerator:*",
          "wafv2:*",
          "shield:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------
# PERMISSION SET 4 — BreakGlass
# Full administrator access for emergencies only
# Used by: On-call security engineer, CISO
# Session: 1 hour MAXIMUM
# Accounts: all accounts
# CRITICAL: Every use triggers immediate SNS alert
# -----------------------------------------------------------
resource "aws_ssoadmin_permission_set" "break_glass" {
  count = var.deploy_identity_center ? 1 : 0

  name             = "BreakGlass"
  description      = "EMERGENCY ONLY. Full AdministratorAccess. 1-hour session maximum. Every use triggers immediate alert to CISO and Security team. All actions logged and reviewed within 24 hours of use."
  instance_arn     = local.sso_instance_arn
  session_duration = "PT${var.break_glass_session_hours}H"

  tags = merge(var.common_tags, {
    Name     = "BreakGlass"
    Purpose  = "Emergency admin access"
    Severity = "CRITICAL"
  })
}

resource "aws_ssoadmin_managed_policy_attachment" "break_glass_admin" {
  count = var.deploy_identity_center ? 1 : 0

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.break_glass[0].arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# -----------------------------------------------------------
# PERMISSION SET 5 — OCCExaminer
# Read-only access for OCC examiners and internal auditors
# Used by: OCC examiners, internal audit, PCI-DSS QSA
# Session: 8 hours (full examination day)
# Accounts: ALL accounts via Audit account cross-account roles
# Time-limited assignment: 30 days per examination period
# -----------------------------------------------------------
resource "aws_ssoadmin_permission_set" "occ_examiner" {
  count = var.deploy_identity_center ? 1 : 0

  name             = "OCCExaminer"
  description      = "Read-only access for OCC examiners, internal audit, and PCI-DSS QSA auditors. Provides independent visibility into all accounts. Assignment is time-limited (30 days per examination). All examiner activity is logged."
  instance_arn     = local.sso_instance_arn
  session_duration = "PT${var.occ_examiner_session_hours}H"

  tags = merge(var.common_tags, {
    Name    = "OCCExaminer"
    Purpose = "OCC examination and internal audit access"
  })
}

resource "aws_ssoadmin_managed_policy_attachment" "occ_examiner_security_audit" {
  count = var.deploy_identity_center ? 1 : 0

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.occ_examiner[0].arn
  managed_policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "aws_ssoadmin_managed_policy_attachment" "occ_examiner_readonly" {
  count = var.deploy_identity_center ? 1 : 0

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.occ_examiner[0].arn
  managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}