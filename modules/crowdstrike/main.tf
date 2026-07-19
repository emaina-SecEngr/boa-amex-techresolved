# ============================================================
# main.tf — CrowdStrike Falcon integration infrastructure
# Module: crowdstrike
#
# DEPLOYMENT ACCOUNT: Security Tooling (368351959735)
# PREREQUISITE: log-archive module complete
# ALL RESOURCES TOGGLED: enable_crowdstrike = false
# Enable when CrowdStrike trial/subscription active
# ============================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

# -----------------------------------------------------------
# FALCON HORIZON IAM ROLE (CSPM)
# CrowdStrike assumes this role to scan AWS configurations
# Same pattern as WizScanner — cross-account trust
# -----------------------------------------------------------
resource "aws_iam_role" "falcon_horizon" {
  count = var.enable_crowdstrike && var.enable_falcon_horizon ? 1 : 0
  name  = "CrowdStrikeFalconHorizon"

  description = "Cross-account role for CrowdStrike Falcon Horizon CSPM scanning. Assumed by CrowdStrike for cloud configuration analysis."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrowdStrikeHorizon"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.crowdstrike_aws_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.crowdstrike_external_id != "" ? var.crowdstrike_external_id : "CS-BOA-AMEX-HORIZON"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "CrowdStrikeFalconHorizon"
    Purpose = "CrowdStrike Falcon Horizon CSPM cross-account scanning"
  })
}

resource "aws_iam_role_policy_attachment" "falcon_horizon_security_audit" {
  count      = var.enable_crowdstrike && var.enable_falcon_horizon ? 1 : 0
  role       = aws_iam_role.falcon_horizon[0].name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "aws_iam_role_policy_attachment" "falcon_horizon_readonly" {
  count      = var.enable_crowdstrike && var.enable_falcon_horizon ? 1 : 0
  role       = aws_iam_role.falcon_horizon[0].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Additional permissions for Falcon Horizon
resource "aws_iam_role_policy" "falcon_horizon_extra" {
  count = var.enable_crowdstrike && var.enable_falcon_horizon ? 1 : 0
  name  = "FalconHorizonExtended"
  role  = aws_iam_role.falcon_horizon[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "FalconHorizonIAMAnalysis"
        Effect = "Allow"
        Action = [
          "iam:GetAccountAuthorizationDetails",
          "iam:GenerateServiceLastAccessedDetails",
          "iam:GetServiceLastAccessedDetails",
          "organizations:DescribeOrganization",
          "organizations:ListAccounts",
          "organizations:ListPolicies",
          "access-analyzer:ListAnalyzers",
          "access-analyzer:ListFindings"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------
# FDR S3 BUCKET
# CrowdStrike Falcon Data Replicator delivers all
# telemetry (detections, process events, network events)
# to this bucket for Security Lake → Sentinel ingestion
# -----------------------------------------------------------
resource "aws_s3_bucket" "crowdstrike_fdr" {
  count  = var.enable_crowdstrike && var.enable_fdr ? 1 : 0
  bucket = var.fdr_bucket_name

  tags = merge(var.common_tags, {
    Name    = var.fdr_bucket_name
    Purpose = "CrowdStrike FDR telemetry - all Falcon detections and events"
  })
}

resource "aws_s3_bucket_versioning" "crowdstrike_fdr" {
  count  = var.enable_crowdstrike && var.enable_fdr ? 1 : 0
  bucket = aws_s3_bucket.crowdstrike_fdr[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "crowdstrike_fdr" {
  count  = var.enable_crowdstrike && var.enable_fdr ? 1 : 0
  bucket = aws_s3_bucket.crowdstrike_fdr[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.log_archive_kms_key_arn != "" ? "aws:kms" : "AES256"
      kms_master_key_id = var.log_archive_kms_key_arn != "" ? var.log_archive_kms_key_arn : null
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "crowdstrike_fdr" {
  count                   = var.enable_crowdstrike && var.enable_fdr ? 1 : 0
  bucket                  = aws_s3_bucket.crowdstrike_fdr[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "crowdstrike_fdr" {
  count  = var.enable_crowdstrike && var.enable_fdr ? 1 : 0
  bucket = aws_s3_bucket.crowdstrike_fdr[0].id

  rule {
    id     = "fdr-lifecycle"
    status = "Enabled"

    filter {
      prefix = ""
    }

    transition {
      days          = var.fdr_retention_days
      storage_class = "GLACIER_IR"
    }

    expiration {
      days = 365
    }
  }
}

# S3 bucket policy — allows CrowdStrike to write FDR data
resource "aws_s3_bucket_policy" "crowdstrike_fdr" {
  count  = var.enable_crowdstrike && var.enable_fdr ? 1 : 0
  bucket = aws_s3_bucket.crowdstrike_fdr[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrowdStrikeFDRWrite"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.crowdstrike_aws_account_id}:root"
        }
        Action = [
          "s3:PutObject",
          "s3:GetBucketLocation",
          "s3:GetBucketAcl"
        ]
        Resource = [
          aws_s3_bucket.crowdstrike_fdr[0].arn,
          "${aws_s3_bucket.crowdstrike_fdr[0].arn}/*"
        ]
      },
      {
        Sid       = "DenyHTTP"
        Effect    = "Deny"
        Principal = { AWS = "*" }
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.crowdstrike_fdr[0].arn,
          "${aws_s3_bucket.crowdstrike_fdr[0].arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.crowdstrike_fdr]
}

# -----------------------------------------------------------
# SSM PARAMETER — stores CrowdStrike CID securely
# SSM Association references this parameter
# Sensor installer reads CID from SSM — never hardcoded
# -----------------------------------------------------------
resource "aws_ssm_parameter" "crowdstrike_cid" {
  count = var.enable_crowdstrike && var.crowdstrike_cid != "" ? 1 : 0
  name  = "/${var.project_prefix}/crowdstrike/cid"
  type  = "SecureString"
  value = var.crowdstrike_cid

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-crowdstrike-cid"
    Purpose = "CrowdStrike Customer ID for sensor installation"
  })
}

# -----------------------------------------------------------
# SSM ASSOCIATION — auto-deploys Falcon sensor
# Runs on ALL EC2 instances in the account
# Uses SSM Distributor to install the package
# New instances auto-enrolled via SSM Agent
# -----------------------------------------------------------
resource "aws_ssm_association" "falcon_sensor" {
  count = var.enable_crowdstrike && var.enable_sensor_deployment && var.crowdstrike_cid != "" ? 1 : 0
  name  = "AWS-ConfigureAWSPackage"

  association_name    = "${var.project_prefix}-crowdstrike-falcon-sensor"
  schedule_expression = var.ssm_association_schedule

  parameters = {
    action  = "Install"
    name    = "CrowdStrike-FalconSensor"
    version = var.sensor_version
    additionalArguments = jsonencode({
      SSM_CS_CCID                      = var.crowdstrike_cid
      SSM_CS_INSTALLTOKEN              = ""
      SSM_CS_GROUPINGTOKEN             = ""
      SSM_CS_WINDOWS_ADDITIONAL_PARAMS = "--tags=BOA-AMEX"
      SSM_CS_LINUX_ADDITIONAL_PARAMS   = "--tags=BOA-AMEX"
    })
  }

  targets {
    key    = "InstanceIds"
    values = ["*"]
  }

  output_location {
    s3_bucket_name = var.fdr_bucket_name
    s3_key_prefix  = "ssm-logs"
  }

  depends_on = [aws_s3_bucket.crowdstrike_fdr]
}

# -----------------------------------------------------------
# LAMBDA — FDR PROCESSOR
# Triggered when CrowdStrike deposits data in S3
# Normalizes CrowdStrike JSON to OCSF format
# Routes to Security Lake for Sentinel ingestion
# -----------------------------------------------------------
resource "aws_iam_role" "fdr_processor" {
  count = var.enable_crowdstrike && var.enable_fdr ? 1 : 0
  name  = "${var.project_prefix}-fdr-processor-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-fdr-processor-role"
    Purpose = "Lambda role for CrowdStrike FDR OCSF normalization"
  })
}

resource "aws_iam_role_policy" "fdr_processor" {
  count = var.enable_crowdstrike && var.enable_fdr ? 1 : 0
  name  = "${var.project_prefix}-fdr-processor-policy"
  role  = aws_iam_role.fdr_processor[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadFDRBucket"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.fdr_bucket_name}",
          "arn:aws:s3:::${var.fdr_bucket_name}/*"
        ]
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Sid    = "KMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = var.log_archive_kms_key_arn != "" ? [var.log_archive_kms_key_arn] : ["*"]
      }
    ]
  })
}

resource "aws_lambda_function" "fdr_processor" {
  count         = var.enable_crowdstrike && var.enable_fdr ? 1 : 0
  filename      = "${path.module}/fdr_processor.zip"
  function_name = "${var.project_prefix}-fdr-processor"
  role          = aws_iam_role.fdr_processor[0].arn
  handler       = "fdr_processor.lambda_handler"
  runtime       = "python3.12"
  timeout       = 300
  memory_size   = 512

  environment {
    variables = {
      PROJECT_PREFIX = var.project_prefix
      REGION         = local.region
      ACCOUNT_ID     = local.account_id
    }
  }

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-fdr-processor"
    Purpose = "Normalizes CrowdStrike FDR data to OCSF for Security Lake"
  })
}

# S3 trigger for Lambda — fires when FDR data arrives
resource "aws_s3_bucket_notification" "fdr_trigger" {
  count  = var.enable_crowdstrike && var.enable_fdr ? 1 : 0
  bucket = aws_s3_bucket.crowdstrike_fdr[0].id

  lambda_function {
    lambda_function_arn = aws_lambda_function.fdr_processor[0].arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "fdr/"
  }

  depends_on = [aws_lambda_permission.fdr_s3]
}

resource "aws_lambda_permission" "fdr_s3" {
  count         = var.enable_crowdstrike && var.enable_fdr ? 1 : 0
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fdr_processor[0].function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.crowdstrike_fdr[0].arn
}

# -----------------------------------------------------------
# CLOUDWATCH LOG GROUP FOR LAMBDA
# -----------------------------------------------------------
resource "aws_cloudwatch_log_group" "fdr_processor" {
  count             = var.enable_crowdstrike && var.enable_fdr ? 1 : 0
  name              = "/aws/lambda/${var.project_prefix}-fdr-processor"
  retention_in_days = 90

  tags = merge(var.common_tags, {
    Name = "${var.project_prefix}-fdr-processor-logs"
  })
}

# -----------------------------------------------------------
# SNS ALERT FOR CRITICAL DETECTIONS
# -----------------------------------------------------------
resource "aws_sns_topic" "crowdstrike_alerts" {
  count = var.enable_crowdstrike && var.security_alert_topic_arn == "" ? 1 : 0
  name  = "${var.project_prefix}-crowdstrike-alerts"

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-crowdstrike-alerts"
    Purpose = "Critical CrowdStrike Falcon detection alerts"
  })
}

resource "aws_sns_topic_subscription" "crowdstrike_email" {
  count     = var.enable_crowdstrike && var.security_alert_topic_arn == "" ? 1 : 0
  topic_arn = aws_sns_topic.crowdstrike_alerts[0].arn
  protocol  = "email"
  endpoint  = var.security_alert_email
}

# EventBridge rule — catches CrowdStrike detections
# via Security Hub integration
resource "aws_cloudwatch_event_rule" "crowdstrike_critical" {
  count       = var.enable_crowdstrike ? 1 : 0
  name        = "${var.project_prefix}-crowdstrike-critical"
  description = "Captures critical CrowdStrike Falcon detections via Security Hub"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        ProductName = [{ wildcard = "*CrowdStrike*" }]
        Severity = {
          Label = ["CRITICAL", "HIGH"]
        }
      }
    }
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_prefix}-crowdstrike-critical"
  })
}

locals {
  alert_topic_arn = var.security_alert_topic_arn != "" ? var.security_alert_topic_arn : (
    var.enable_crowdstrike && length(aws_sns_topic.crowdstrike_alerts) > 0 ? aws_sns_topic.crowdstrike_alerts[0].arn : ""
  )
}

resource "aws_cloudwatch_event_target" "crowdstrike_sns" {
  count     = var.enable_crowdstrike && local.alert_topic_arn != "" ? 1 : 0
  rule      = aws_cloudwatch_event_rule.crowdstrike_critical[0].name
  target_id = "CrowdStrikeSNS"
  arn       = local.alert_topic_arn
}