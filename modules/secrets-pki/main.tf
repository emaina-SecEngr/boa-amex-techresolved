# ============================================================
# main.tf — Secrets Management & PKI
# Module: secrets-pki
#
# Centralized secret management (Secrets Manager) and
# PKI infrastructure (ACM Private CA) for the banking platform.
#
# HOW THIS WORKS:
#   Secrets stored in Security Tooling account
#   Workload accounts retrieve secrets at runtime via
#   cross-account resource policies — applications never
#   store credentials locally.
#
#   Private CA issues mTLS certificates for inter-service
#   communication. LBB-CardAuth → LBB-FraudEngine requires
#   mutual TLS — both sides present certificates.
#
# DEPLOYMENT: Security Tooling (368351959735)
# ============================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

# ═══════════════════════════════════════════════════════════
# KMS KEY — encrypts all secrets at rest
# Dedicated key for Secrets Manager (not shared with S3/RDS)
# ═══════════════════════════════════════════════════════════

resource "aws_kms_key" "secrets" {
  count               = var.enable_secrets_management ? 1 : 0
  description         = "KMS key for Secrets Manager — encrypts all application credentials"
  enable_key_rotation = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSecurityToolingAdmin"
        Effect = "Allow"
        Principal = { AWS = "arn:aws:iam::${local.account_id}:root" }
        Action = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowSecretsManagerUse"
        Effect = "Allow"
        Principal = { Service = "secretsmanager.amazonaws.com" }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowWorkloadAccountsDecrypt"
        Effect = "Allow"
        Principal = {
          AWS = [for id in var.workload_account_ids : "arn:aws:iam::${id}:root"]
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${local.region}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-secrets-kms-key"
    Purpose = "Encrypts all Secrets Manager credentials"
  })
}

resource "aws_kms_alias" "secrets" {
  count         = var.enable_secrets_management ? 1 : 0
  name          = "alias/${var.project_prefix}-secrets"
  target_key_id = aws_kms_key.secrets[0].key_id
}

# ═══════════════════════════════════════════════════════════
# DATABASE SECRETS — one per workload database
# ═══════════════════════════════════════════════════════════

resource "aws_secretsmanager_secret" "database" {
  for_each = var.enable_secrets_management ? {
    for secret in var.database_secrets : secret.name => secret
  } : {}

  name        = "${var.project_prefix}/${each.value.name}"
  description = each.value.description
  kms_key_id  = aws_kms_key.secrets[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowWorkloadAccountAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${each.value.target_account}:root"
        }
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name           = "${var.project_prefix}-${each.value.name}"
    SecretType     = "DatabaseCredential"
    Engine         = each.value.engine
    TargetAccount  = each.value.target_account
    RotationDays   = tostring(each.value.rotation_days)
  })
}

resource "aws_secretsmanager_secret_rotation" "database" {
  for_each = var.enable_secrets_management ? {
    for secret in var.database_secrets : secret.name => secret
  } : {}

  secret_id           = aws_secretsmanager_secret.database[each.key].id
  rotation_lambda_arn = aws_lambda_function.secret_rotator[0].arn

  rotation_rules {
    automatically_after_days = each.value.rotation_days
  }
}

# ═══════════════════════════════════════════════════════════
# API SECRETS — API keys, tokens, inter-service auth
# ═══════════════════════════════════════════════════════════

resource "aws_secretsmanager_secret" "api" {
  for_each = var.enable_secrets_management ? {
    for secret in var.api_secrets : secret.name => secret
  } : {}

  name        = "${var.project_prefix}/${each.value.name}"
  description = each.value.description
  kms_key_id  = aws_kms_key.secrets[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowOrgAccess"
        Effect = "Allow"
        Principal = "*"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalOrgID" = var.organization_id
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name         = "${var.project_prefix}-${each.value.name}"
    SecretType   = "APICredential"
    RotationDays = tostring(each.value.rotation_days)
  })
}

# ═══════════════════════════════════════════════════════════
# ROTATION LAMBDA — rotates database credentials automatically
# ═══════════════════════════════════════════════════════════

resource "aws_iam_role" "secret_rotator" {
  count = var.enable_secrets_management ? 1 : 0
  name  = "${var.project_prefix}-secret-rotator-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.common_tags, { Name = "${var.project_prefix}-secret-rotator-role" })
}

resource "aws_iam_role_policy" "secret_rotator" {
  count = var.enable_secrets_management ? 1 : 0
  name  = "${var.project_prefix}-secret-rotator-policy"
  role  = aws_iam_role.secret_rotator[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManagerAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage",
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetRandomPassword"
        ]
        Resource = "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:${var.project_prefix}/*"
      },
      {
        Sid      = "KMSDecrypt"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey"]
        Resource = aws_kms_key.secrets[0].arn
      },
      {
        Sid      = "CloudWatchLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_lambda_function" "secret_rotator" {
  count         = var.enable_secrets_management ? 1 : 0
  filename      = "${path.module}/secret_rotator.zip"
  function_name = "${var.project_prefix}-secret-rotator"
  role          = aws_iam_role.secret_rotator[0].arn
  handler       = "secret_rotator.lambda_handler"
  runtime       = "python3.12"
  timeout       = 60
  memory_size   = 256

  environment {
    variables = {
      PROJECT_PREFIX = var.project_prefix
    }
  }

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-secret-rotator"
    Purpose = "Automatic credential rotation for all database and API secrets"
  })
}

resource "aws_lambda_permission" "secrets_manager" {
  count         = var.enable_secrets_management ? 1 : 0
  statement_id  = "AllowSecretsManager"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.secret_rotator[0].function_name
  principal     = "secretsmanager.amazonaws.com"
}

# ═══════════════════════════════════════════════════════════
# ACM PRIVATE CA — internal mTLS certificates
# ═══════════════════════════════════════════════════════════

resource "aws_acmpca_certificate_authority" "internal" {
  count = var.enable_private_ca ? 1 : 0
  type  = "ROOT"

  certificate_authority_configuration {
    key_algorithm     = "RSA_2048"
    signing_algorithm = "SHA256WITHRSA"

    subject {
      common_name  = var.ca_common_name
      organization = var.ca_organization
      country      = "US"
      state        = "Arizona"
    }
  }

  revocation_configuration {
    crl_configuration {
      enabled            = true
      expiration_in_days = 7
      s3_bucket_name     = "${var.project_prefix}-pki-crl-${local.account_id}"
    }
  }

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-internal-ca"
    Purpose = "Private CA for mTLS between banking microservices"
  })
}

# ═══════════════════════════════════════════════════════════
# ROTATION FAILURE ALARM — alert if rotation fails
# ═══════════════════════════════════════════════════════════

resource "aws_sns_topic" "secret_alerts" {
  count = var.enable_secrets_management ? 1 : 0
  name  = "${var.project_prefix}-secret-rotation-alerts"

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-secret-rotation-alerts"
    Purpose = "Alerts for failed secret rotations and certificate expiry"
  })
}

resource "aws_sns_topic_subscription" "secret_email" {
  count     = var.enable_secrets_management ? 1 : 0
  topic_arn = aws_sns_topic.secret_alerts[0].arn
  protocol  = "email"
  endpoint  = var.security_alert_email
}

resource "aws_cloudwatch_metric_alarm" "rotation_failure" {
  count               = var.enable_secrets_management ? 1 : 0
  alarm_name          = "${var.project_prefix}-secret-rotation-failure"
  alarm_description   = "CRITICAL: Secret rotation failed — credentials may be stale. PCI-DSS Req 8.2.4 violation risk."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 3600
  statistic           = "Sum"
  threshold           = 0

  dimensions = {
    FunctionName = aws_lambda_function.secret_rotator[0].function_name
  }

  alarm_actions = [aws_sns_topic.secret_alerts[0].arn]

  tags = merge(var.common_tags, {
    Name = "${var.project_prefix}-rotation-failure-alarm"
  })
}