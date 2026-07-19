# ============================================================
# LBBS Terraform — Encryption Posture
# ============================================================
# Ensures ALL data is encrypted at rest and in transit.
#
# ENCRYPTION TYPES:
#   At Rest:    Data encrypted when stored on disk
#   In Transit: Data encrypted when moving over the network
#
# WHAT THIS FILE CREATES:
#   1. KMS Keys (AWS-managed encryption keys)
#   2. Encryption policies for every service
#   3. S3 bucket policies enforcing HTTPS
#   4. RDS encryption configuration
#   5. EBS default encryption
#   6. CloudTrail encryption
#   7. SNS encryption
#   8. SQS encryption (if used)
#
# WHY ENCRYPTION MATTERS:
#   Without encryption:
#     Hacker steals a hard drive → reads all data in plain text
#     Hacker intercepts network traffic → reads passwords
#
#   With encryption:
#     Hacker steals a hard drive → sees random gibberish
#     Hacker intercepts network traffic → sees random gibberish
#     Data is USELESS without the encryption key
#
# COMPLIANCE:
#   SOC 2:    Requires encryption at rest and in transit
#   HIPAA:    Requires encryption of health data
#   PCI-DSS:  Requires encryption of payment data
#   FERPA:    Requires encryption of student data (our case!)
# ============================================================


# ─────────────────────────────────────────────────────
# 1. KMS KEYS — The Master Encryption Keys
# ─────────────────────────────────────────────────────
# KMS = Key Management Service
# These are the MASTER KEYS that encrypt everything.
#
# How it works:
#   Data → encrypted with Data Key → Data Key encrypted with KMS Key
#   This is called ENVELOPE ENCRYPTION:
#     KMS Key (never leaves AWS) → encrypts Data Key
#     Data Key → encrypts your actual data
#     Even AWS employees cannot read your data
# ─────────────────────────────────────────────────────

# Master key for database encryption
resource "aws_kms_key" "database" {
  description             = "Encryption key for LBBS database (RDS)"
  deletion_window_in_days = 30
  enable_key_rotation     = true  # Automatically rotate key yearly

  # WHO can use this key:
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Account root can manage the key
      {
        Sid    = "RootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      # RDS service can use the key to encrypt/decrypt
      {
        Sid    = "RDSAccess"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:ReEncrypt*",
          "kms:DescribeKey",
          "kms:CreateGrant",
        ]
        Resource = "*"
      },
      # Backend role can decrypt (to read database)
      {
        Sid    = "BackendDecrypt"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.lbbs_backend_role.arn
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
        ]
        Resource = "*"
      },
    ]
  })

  tags = { Name = "${var.project_name}-database-key" }
}

resource "aws_kms_alias" "database" {
  name          = "alias/${var.project_name}-database"
  target_key_id = aws_kms_key.database.key_id
}

# Master key for S3 bucket encryption
resource "aws_kms_key" "storage" {
  description             = "Encryption key for LBBS S3 storage"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey",
        ]
        Resource = "*"
      },
      {
        Sid    = "BackendAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.lbbs_backend_role.arn
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey",
        ]
        Resource = "*"
      },
    ]
  })

  tags = { Name = "${var.project_name}-storage-key" }
}

resource "aws_kms_alias" "storage" {
  name          = "alias/${var.project_name}-storage"
  target_key_id = aws_kms_key.storage.key_id
}

# Master key for Secrets Manager
resource "aws_kms_key" "secrets" {
  description             = "Encryption key for LBBS secrets"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "SecretsManagerAccess"
        Effect = "Allow"
        Principal = {
          Service = "secretsmanager.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey",
          "kms:CreateGrant",
        ]
        Resource = "*"
      },
      {
        Sid    = "BackendDecrypt"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.lbbs_backend_role.arn
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
        ]
        Resource = "*"
      },
    ]
  })

  tags = { Name = "${var.project_name}-secrets-key" }
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.project_name}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

# Master key for logs and audit trail
resource "aws_kms_key" "logs" {
  description             = "Encryption key for LBBS logs and audit"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "CloudWatchAccess"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey",
        ]
        Resource = "*"
        Condition = {
          ArnEquals = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/lbbs/*"
          }
        }
      },
      {
        Sid    = "SNSAccess"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey",
        ]
        Resource = "*"
      },
    ]
  })

  tags = { Name = "${var.project_name}-logs-key" }
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${var.project_name}-logs"
  target_key_id = aws_kms_key.logs.key_id
}


# ─────────────────────────────────────────────────────
# 2. S3 ENCRYPTION — Force Encryption on Every Object
# ─────────────────────────────────────────────────────
# Every file uploaded to S3 MUST be encrypted.
# If someone tries to upload without encryption → DENIED.
# ─────────────────────────────────────────────────────

# Force KMS encryption on the reports bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "reports_kms" {
  bucket = aws_s3_bucket.reports.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.storage.arn
    }
    bucket_key_enabled = true  # Reduces KMS API calls and cost
  }
}

# Policy: DENY any upload without encryption
resource "aws_s3_bucket_policy" "reports_encryption_policy" {
  bucket = aws_s3_bucket.reports.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Force HTTPS (encryption in transit)
      {
        Sid       = "DenyHTTP"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.reports.arn,
          "${aws_s3_bucket.reports.arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      # Force encryption on upload (encryption at rest)
      {
        Sid       = "DenyUnencryptedUpload"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.reports.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      },
      # Force TLS 1.2 minimum
      {
        Sid       = "DenyOldTLS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.reports.arn,
          "${aws_s3_bucket.reports.arn}/*",
        ]
        Condition = {
          NumericLessThan = {
            "s3:TlsVersion" = "1.2"
          }
        }
      },
    ]
  })
}


# ─────────────────────────────────────────────────────
# 3. EBS DEFAULT ENCRYPTION — All Disk Volumes Encrypted
# ─────────────────────────────────────────────────────
# Every EBS volume (disk) created in this region will be
# automatically encrypted. No exceptions. No opt-out.
# ─────────────────────────────────────────────────────

resource "aws_ebs_encryption_by_default" "enabled" {
  enabled = true
}

resource "aws_ebs_default_kms_key" "default" {
  key_arn = aws_kms_key.storage.arn
}


# ─────────────────────────────────────────────────────
# 4. SNS ENCRYPTION — Alert Messages Encrypted
# ─────────────────────────────────────────────────────

resource "aws_sns_topic" "alerts_encrypted" {
  name              = "${var.project_name}-alerts-encrypted"
  kms_master_key_id = aws_kms_key.logs.id

  tags = { Name = "${var.project_name}-alerts-encrypted" }
}


# ─────────────────────────────────────────────────────
# 5. CLOUDTRAIL — Encrypted Audit Log of ALL API Calls
# ─────────────────────────────────────────────────────
# CloudTrail records EVERY API call made in your AWS account.
# "Who did what, when, from where"
# Required for SOC 2, HIPAA, PCI-DSS, FERPA compliance.
# ─────────────────────────────────────────────────────

# S3 bucket for CloudTrail logs (encrypted)
resource "aws_s3_bucket" "cloudtrail" {
  bucket        = "${var.project_name}-cloudtrail-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  tags          = { Name = "${var.project_name}-cloudtrail-logs" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.logs.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket                  = aws_s3_bucket.cloudtrail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail.arn
      },
      {
        Sid    = "CloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      # Force HTTPS
      {
        Sid       = "DenyHTTP"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.cloudtrail.arn,
          "${aws_s3_bucket.cloudtrail.arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
    ]
  })
}

# CloudTrail itself
resource "aws_cloudtrail" "lbbs" {
  name                       = "${var.project_name}-audit-trail"
  s3_bucket_name             = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail      = false
  enable_logging             = true
  kms_key_id                 = aws_kms_key.logs.arn

  # Log all management events (create, delete, modify resources)
  event_selector {
    read_write_type           = "All"
    include_management_events = true

    # Also log S3 data events (who read/wrote what files)
    data_resource {
      type   = "AWS::S3::Object"
      values = ["${aws_s3_bucket.reports.arn}/"]
    }
  }

  tags = { Name = "${var.project_name}-cloudtrail" }
}


# ─────────────────────────────────────────────────────
# 6. GUARDDUTY — Threat Detection
# ─────────────────────────────────────────────────────
# Continuously monitors for:
#   - Compromised credentials
#   - Unusual API calls
#   - Cryptocurrency mining
#   - Data exfiltration
#   - Unauthorized access
# ─────────────────────────────────────────────────────

resource "aws_guardduty_detector" "lbbs" {
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
  }

  tags = { Name = "${var.project_name}-guardduty" }
}


# ─────────────────────────────────────────────────────
# 7. AWS CONFIG — Continuous Compliance Monitoring
# ─────────────────────────────────────────────────────
# Monitors ALL resources and checks against rules:
#   "Is RDS encrypted?" → Yes ✅ / No ❌ VIOLATION
#   "Is S3 public?" → No ✅ / Yes ❌ VIOLATION
# ─────────────────────────────────────────────────────

resource "aws_config_configuration_recorder" "lbbs" {
  name     = "${var.project_name}-config-recorder"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported = true
  }
}

resource "aws_iam_role" "config_role" {
  name = "${var.project_name}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "config.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config_policy" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

# Rule: RDS must be encrypted
resource "aws_config_config_rule" "rds_encrypted" {
  name = "${var.project_name}-rds-encryption-enabled"

  source {
    owner             = "AWS"
    source_identifier = "RDS_STORAGE_ENCRYPTED"
  }

  depends_on = [aws_config_configuration_recorder.lbbs]
}

# Rule: S3 buckets must be encrypted
resource "aws_config_config_rule" "s3_encrypted" {
  name = "${var.project_name}-s3-encryption-enabled"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.lbbs]
}

# Rule: S3 buckets must not be public
resource "aws_config_config_rule" "s3_not_public" {
  name = "${var.project_name}-s3-not-public"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder.lbbs]
}

# Rule: EBS volumes must be encrypted
resource "aws_config_config_rule" "ebs_encrypted" {
  name = "${var.project_name}-ebs-encryption-enabled"

  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }

  depends_on = [aws_config_configuration_recorder.lbbs]
}

# Rule: IAM users must have MFA
resource "aws_config_config_rule" "mfa_enabled" {
  name = "${var.project_name}-iam-mfa-enabled"

  source {
    owner             = "AWS"
    source_identifier = "IAM_USER_MFA_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.lbbs]
}

# Rule: Root account must have MFA
resource "aws_config_config_rule" "root_mfa" {
  name = "${var.project_name}-root-mfa-enabled"

  source {
    owner             = "AWS"
    source_identifier = "ROOT_ACCOUNT_MFA_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.lbbs]
}
