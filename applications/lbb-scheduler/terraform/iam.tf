# ============================================================
# LBBS Terraform — IAM (Identity & Access Management)
# ============================================================
# Creates: Policies, Roles, Groups, Users, MFA, Password Policy
# ============================================================

data "aws_caller_identity" "current" {}

# ─────────────────────────────────────────────────────
# 1. IAM POLICIES
# ─────────────────────────────────────────────────────

resource "aws_iam_policy" "lbbs_backend_policy" {
  name        = "${var.project_name}-backend-policy"
  description = "Permissions for LBBS backend service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RDSAccess"
        Effect = "Allow"
        Action = [
          "rds-db:connect",
          "rds:DescribeDBInstances",
        ]
        Resource = "*"
      },
      {
        Sid    = "SecretsAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:${var.project_name}/*"
      },
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-reports",
          "arn:aws:s3:::${var.project_name}-reports/*",
        ]
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "arn:aws:logs:*:*:log-group:/lbbs/*"
      },
      {
        Sid    = "SESAccess"
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ses:FromAddress" = "noreply@lifebeyondthebooksaz.org"
          }
        }
      },
    ]
  })
}

resource "aws_iam_policy" "lbbs_admin_policy" {
  name        = "${var.project_name}-admin-policy"
  description = "Full LBBS admin access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECSManagement"
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:StopTask",
        ]
        Resource = "*"
      },
      {
        Sid    = "ViewLogs"
        Effect = "Allow"
        Action = [
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:DescribeLogGroups",
        ]
        Resource = "arn:aws:logs:*:*:log-group:/lbbs/*"
      },
      {
        Sid    = "CloudWatchMonitoring"
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricData",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetDashboard",
        ]
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_policy" "lbbs_readonly_policy" {
  name        = "${var.project_name}-readonly-policy"
  description = "Read-only access to LBBS AWS resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadOnlyAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "logs:GetLogEvents",
          "cloudwatch:GetMetricData",
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-reports/*",
          "arn:aws:logs:*:*:log-group:/lbbs/*",
        ]
      },
    ]
  })
}

resource "aws_iam_policy" "lbbs_deny_dangerous" {
  name        = "${var.project_name}-deny-dangerous-actions"
  description = "Explicitly deny destructive actions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyDangerousActions"
        Effect = "Deny"
        Action = [
          "iam:CreateUser",
          "iam:DeleteUser",
          "iam:AttachUserPolicy",
          "iam:DetachUserPolicy",
          "ec2:TerminateInstances",
          "rds:DeleteDBInstance",
          "rds:DeleteDBCluster",
          "s3:DeleteBucket",
          "organizations:LeaveOrganization",
          "account:CloseAccount",
        ]
        Resource = "*"
      },
    ]
  })
}

# ─────────────────────────────────────────────────────
# 2. IAM ROLES
# ─────────────────────────────────────────────────────

resource "aws_iam_role" "lbbs_backend_role" {
  name = "${var.project_name}-backend-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "ecs-tasks.amazonaws.com",
            "ec2.amazonaws.com",
          ]
        }
        Action = "sts:AssumeRole"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "backend_policy_attach" {
  role       = aws_iam_role.lbbs_backend_role.name
  policy_arn = aws_iam_policy.lbbs_backend_policy.arn
}

resource "aws_iam_role_policy_attachment" "backend_deny_attach" {
  role       = aws_iam_role.lbbs_backend_role.name
  policy_arn = aws_iam_policy.lbbs_deny_dangerous.arn
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.project_name}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "cicd_deployment_role" {
  name = "${var.project_name}-cicd-deployment-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "cicd_policy" {
  name = "${var.project_name}-cicd-policy"
  role = aws_iam_role.cicd_deployment_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAccess"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
        ]
        Resource = "*"
      },
      {
        Sid    = "ECSDeployment"
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:RegisterTaskDefinition",
          "ecs:DeregisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
        ]
        Resource = "*"
      },
      {
        Sid    = "PassRole"
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = [
          aws_iam_role.lbbs_backend_role.arn,
          aws_iam_role.ecs_execution_role.arn,
        ]
      },
    ]
  })
}

# ─────────────────────────────────────────────────────
# 3. IAM GROUPS
# ─────────────────────────────────────────────────────

resource "aws_iam_group" "lbbs_admins" {
  name = "${var.project_name}-admins"
}

resource "aws_iam_group_policy_attachment" "admins_policy" {
  group      = aws_iam_group.lbbs_admins.name
  policy_arn = aws_iam_policy.lbbs_admin_policy.arn
}

resource "aws_iam_group_policy_attachment" "admins_deny" {
  group      = aws_iam_group.lbbs_admins.name
  policy_arn = aws_iam_policy.lbbs_deny_dangerous.arn
}

resource "aws_iam_group" "lbbs_developers" {
  name = "${var.project_name}-developers"
}

resource "aws_iam_group_policy_attachment" "developers_readonly" {
  group      = aws_iam_group.lbbs_developers.name
  policy_arn = aws_iam_policy.lbbs_readonly_policy.arn
}

resource "aws_iam_group_policy_attachment" "developers_deny" {
  group      = aws_iam_group.lbbs_developers.name
  policy_arn = aws_iam_policy.lbbs_deny_dangerous.arn
}

resource "aws_iam_group" "district_groups" {
  for_each = toset(var.school_districts)
  name     = "${var.project_name}-district-${each.value}"
}

resource "aws_iam_group_policy_attachment" "district_readonly" {
  for_each   = toset(var.school_districts)
  group      = aws_iam_group.district_groups[each.value].name
  policy_arn = aws_iam_policy.lbbs_readonly_policy.arn
}

# ─────────────────────────────────────────────────────
# 4. IAM USERS
# ─────────────────────────────────────────────────────

resource "aws_iam_user" "admin_users" {
  for_each = { for u in var.admin_users : u.username => u }
  name     = each.value.username

  tags = {
    Email = each.value.email
    Role  = each.value.role
  }
}

resource "aws_iam_user_group_membership" "admin_memberships" {
  for_each = { for u in var.admin_users : u.username => u }
  user     = aws_iam_user.admin_users[each.key].name
  groups   = [aws_iam_group.lbbs_admins.name]
}

# ─────────────────────────────────────────────────────
# 5. OKTA OIDC FEDERATION (uncomment when ready)
# ─────────────────────────────────────────────────────
# resource "aws_iam_openid_connect_provider" "okta" {
#   url             = "https://${var.okta_domain}"
#   client_id_list  = [var.okta_client_id]
#   thumbprint_list = ["your-okta-certificate-thumbprint"]
# }
#
# resource "aws_iam_role" "okta_sso_role" {
#   name = "${var.project_name}-okta-sso-role"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect = "Allow"
#       Principal = { Federated = aws_iam_openid_connect_provider.okta.arn }
#       Action = "sts:AssumeRoleWithWebIdentity"
#       Condition = { StringEquals = { "${var.okta_domain}:aud" = var.okta_client_id } }
#     }]
#   })
# }

# ─────────────────────────────────────────────────────
# 6. PASSWORD POLICY
# ─────────────────────────────────────────────────────

resource "aws_iam_account_password_policy" "strict" {
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_numbers                = true
  require_uppercase_characters   = true
  require_symbols                = true
  allow_users_to_change_password = true
  max_password_age               = 90
  password_reuse_prevention      = 12
  hard_expiry                    = false
}

# ─────────────────────────────────────────────────────
# 7. MFA ENFORCEMENT
# ─────────────────────────────────────────────────────

resource "aws_iam_policy" "enforce_mfa" {
  name        = "${var.project_name}-enforce-mfa"
  description = "Deny all actions unless MFA is present"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowManageOwnMFA"
        Effect = "Allow"
        Action = [
          "iam:CreateVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:ResyncMFADevice",
          "iam:ListMFADevices",
        ]
        Resource = [
          "arn:aws:iam::*:mfa/$${aws:username}",
          "arn:aws:iam::*:user/$${aws:username}",
        ]
      },
      {
        Sid    = "DenyAllWithoutMFA"
        Effect = "Deny"
        NotAction = [
          "iam:CreateVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:ListMFADevices",
          "iam:ResyncMFADevice",
          "sts:GetSessionToken",
        ]
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      },
    ]
  })
}

resource "aws_iam_group_policy_attachment" "admins_mfa" {
  group      = aws_iam_group.lbbs_admins.name
  policy_arn = aws_iam_policy.enforce_mfa.arn
}

resource "aws_iam_group_policy_attachment" "developers_mfa" {
  group      = aws_iam_group.lbbs_developers.name
  policy_arn = aws_iam_policy.enforce_mfa.arn
}
