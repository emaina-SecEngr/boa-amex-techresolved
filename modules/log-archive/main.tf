# ============================================================
# main.tf — Production log archive
# Module: log-archive
#
# DEPLOYMENT ACCOUNT: Security Tooling (368351959735)
# PREREQUISITE: Phase 1 complete
# REQUIRED BY: guardduty, security-hub, security-lake,
#              sentinel-connector (all Phase 2 modules)
# ============================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  region      = data.aws_region.current.name
  bucket_name = var.log_archive_bucket_name
}

# -----------------------------------------------------------
# KMS KEY — encrypts all logs at rest
# Customer Managed Key (CMK) — we control it, not AWS
# Required for PCI-DSS Requirement 3.5
# -----------------------------------------------------------
resource "aws_kms_key" "log_archive" {
  description             = "${var.project_prefix} log archive encryption key"
  deletion_window_in_days = var.kms_key_deletion_window_days
  enable_key_rotation     = var.kms_key_rotation_enabled
  multi_region            = false

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudTrailEncryption"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "kms:EncryptionContext:aws:cloudtrail:arn" = "arn:aws:cloudtrail:*:*:trail/*"
          }
        }
      },
      {
        Sid    = "AllowGuardDutyEncryption"
        Effect = "Allow"
        Principal = {
          Service = "guardduty.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:Decrypt"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowConfigEncryption"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:Decrypt"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowSecurityLakeEncryption"
        Effect = "Allow"
        Principal = {
          Service = "securitylake.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:Decrypt"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowOrgAccountsDecrypt"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
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
    Name    = "${var.project_prefix}-log-archive-kms"
    Purpose = "Encrypts all security logs in Log Archive bucket"
  })
}

resource "aws_kms_alias" "log_archive" {
  name          = "alias/${var.project_prefix}-log-archive"
  target_key_id = aws_kms_key.log_archive.key_id
}

# -----------------------------------------------------------
# S3 BUCKET — the log archive
# Object Lock enabled for WORM immutability
# Cannot be deleted or modified for retention period
# -----------------------------------------------------------
resource "aws_s3_bucket" "log_archive" {
  bucket = local.bucket_name

  # Prevent accidental deletion via Terraform
  lifecycle {
    prevent_destroy = true
  }

  tags = merge(var.common_tags, {
    Name            = local.bucket_name
    DataClass       = "Restricted-SecurityLogs"
    RetentionYears  = "7"
    ComplianceScope = "PCI-DSS-v4 OCC-12CFR30"
  })
}

# Object Lock — WORM immutability
resource "aws_s3_bucket_object_lock_configuration" "log_archive" {
  count  = var.enable_object_lock ? 1 : 0
  bucket = aws_s3_bucket.log_archive.id

  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = var.object_lock_retention_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.log_archive]
}

# Versioning — required for Object Lock
resource "aws_s3_bucket_versioning" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# KMS encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.log_archive.arn
    }
    bucket_key_enabled = true
  }
}

# Block all public access — non-negotiable
resource "aws_s3_bucket_public_access_block" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy — move logs through storage tiers
resource "aws_s3_bucket_lifecycle_configuration" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id

  rule {
    id     = "log-archive-lifecycle"
    status = "Enabled"

    filter {
      prefix = ""
    }

    transition {
      days          = var.standard_retention_days
      storage_class = "GLACIER_IR"
    }

    transition {
      days          = var.glacier_instant_retention_days
      storage_class = "DEEP_ARCHIVE"
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER_IR"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.glacier_deep_archive_retention_days
    }
  }
}

# -----------------------------------------------------------
# S3 BUCKET POLICY
# Allows all Organization accounts to write logs here
# Denies any deletion or modification
# Enforces encryption in transit (HTTPS only)
# -----------------------------------------------------------
resource "aws_s3_bucket_policy" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [

      # CloudTrail delivery from all org accounts
      {
        Sid    = "AllowCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.log_archive.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"    = "bucket-owner-full-control"
            "aws:SourceOrgID" = var.organization_id
          }
        }
      },

      # CloudTrail ACL check
      {
        Sid    = "AllowCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.log_archive.arn
        Condition = {
          StringEquals = {
            "aws:SourceOrgID" = var.organization_id
          }
        }
      },

      # GuardDuty findings export
      {
        Sid    = "AllowGuardDutyWrite"
        Effect = "Allow"
        Principal = {
          Service = "guardduty.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.log_archive.arn}/guardduty/*"
        Condition = {
          StringEquals = {
            "aws:SourceOrgID" = var.organization_id
          }
        }
      },

      # Config delivery from all org accounts
      {
        Sid    = "AllowConfigWrite"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.log_archive.arn}/*"
        Condition = {
          StringEquals = {
            "aws:SourceOrgID" = var.organization_id
          }
        }
      },

      # Config ACL check
      {
        Sid    = "AllowConfigAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.log_archive.arn
        Condition = {
          StringEquals = {
            "aws:SourceOrgID" = var.organization_id
          }
        }
      },

      # Security Lake write access
      {
        Sid    = "AllowSecurityLakeWrite"
        Effect = "Allow"
        Principal = {
          Service = "securitylake.amazonaws.com"
        }
        Action = [
          "s3:PutObject",
          "s3:GetBucketAcl",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.log_archive.arn,
          "${aws_s3_bucket.log_archive.arn}/*"
        ]
      },

      # Allow all org accounts to write logs
      {
        Sid    = "AllowOrgAccountsWrite"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.log_archive.arn}/*"
        Condition = {
          StringEquals = {
            "aws:PrincipalOrgID"              = var.organization_id
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      },

      # Allow all org accounts bucket ACL check
      {
        Sid    = "AllowOrgAccountsAclCheck"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.log_archive.arn
        Condition = {
          StringEquals = {
            "aws:PrincipalOrgID" = var.organization_id
          }
        }
      },

      # Deny unencrypted uploads — everything must use KMS
      {
        Sid    = "DenyUnencryptedUploads"
        Effect = "Deny"
        Principal = {
          AWS = "*"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.log_archive.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      },

      # Deny HTTP — HTTPS only
      {
        Sid    = "DenyHTTPAccess"
        Effect = "Deny"
        Principal = {
          AWS = "*"
        }
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.log_archive.arn,
          "${aws_s3_bucket.log_archive.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },

      # Deny deletion — logs are immutable
      {
        Sid    = "DenyLogDeletion"
        Effect = "Deny"
        Principal = {
          AWS = "*"
        }
        Action = [
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
          "s3:DeleteBucket",
          "s3:PutLifecycleConfiguration"
        ]
        Resource = [
          aws_s3_bucket.log_archive.arn,
          "${aws_s3_bucket.log_archive.arn}/*"
        ]
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.log_archive]
}

# -----------------------------------------------------------
# ACCESS LOGGING
# Log all access to the log archive bucket itself
# Creates an audit trail OF the audit trail
# OCC requirement: access to security logs must be logged
# -----------------------------------------------------------
resource "aws_s3_bucket" "log_archive_access_logs" {
  bucket = "${local.bucket_name}-access-logs"

  tags = merge(var.common_tags, {
    Name    = "${local.bucket_name}-access-logs"
    Purpose = "Access logs for the log archive bucket itself"
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.log_archive_access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.log_archive.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket                  = aws_s3_bucket.log_archive_access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "log_archive" {
  bucket        = aws_s3_bucket.log_archive.id
  target_bucket = aws_s3_bucket.log_archive_access_logs.id
  target_prefix = "access-logs/"
}

# -----------------------------------------------------------
# SNS ALERT — unauthorized access to log archive
# Fires if anyone tries to access logs without permission
# -----------------------------------------------------------
resource "aws_sns_topic" "log_archive_alerts" {
  name = "${var.project_prefix}-log-archive-alerts"

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-log-archive-alerts"
    Purpose = "Alerts for unauthorized log archive access"
  })
}

resource "aws_sns_topic_subscription" "log_archive_alert_email" {
  topic_arn = aws_sns_topic.log_archive_alerts.arn
  protocol  = "email"
  endpoint  = var.security_alert_email
}

# CloudWatch alarm for unauthorized S3 access
resource "aws_cloudwatch_metric_alarm" "unauthorized_log_access" {
  alarm_name          = "${var.project_prefix}-unauthorized-log-archive-access"
  alarm_description   = "CRITICAL: Unauthorized access attempt on Log Archive bucket. Potential evidence tampering."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "4xxErrors"
  namespace           = "AWS/S3"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    BucketName = aws_s3_bucket.log_archive.id
    FilterId   = "EntireBucket"
  }

  alarm_actions = [aws_sns_topic.log_archive_alerts.arn]

  tags = merge(var.common_tags, {
    Name     = "${var.project_prefix}-unauthorized-log-archive-access"
    Severity = "CRITICAL"
  })
}