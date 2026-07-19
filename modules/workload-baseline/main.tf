# ============================================================
# main.tf — Workload security baseline
# Module: workload-baseline
#
# THE MOST IMPORTANT MODULE IN THE PROJECT
# Applied to EVERY workload account — identical controls
# BofA runs this 200+ times. We run it 3 times.
# LBB Scheduler is the workload deployed into these accounts.
#
# DEPLOYMENT: per workload account (Dev, PCI-CDE, Pipeline)
# ============================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  name       = "${var.project_prefix}-${var.account_name}"

  default_tags = merge(var.common_tags, {
    Account        = var.account_name
    Environment    = var.environment
    DataClass      = var.data_classification
    SecurityPreset = var.security_preset
    Workload       = "LBB-Scheduler"
  })
}

# ═══════════════════════════════════════════════════════════
# VPC — three-tier subnet architecture
# Public (ALB only) → Private (LBB app) → Isolated (LBB DB)
# ═══════════════════════════════════════════════════════════

resource "aws_vpc" "workload" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.default_tags, {
    Name    = "${local.name}-vpc"
    Purpose = "LBB Scheduler workload VPC"
    Tier    = "workload"
  })
}

# --- Public subnets (ALB only — never EC2 directly) ---
resource "aws_subnet" "public" {
  count             = var.enable_public_subnets ? length(var.availability_zones) : 0
  vpc_id            = aws_vpc.workload.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(local.default_tags, {
    Name = "${local.name}-public-${var.availability_zones[count.index]}"
    Tier = "public"
    Note = "ALB only - never place EC2 or LBB containers here"
  })
}

# --- Private subnets (LBB FastAPI backend — ECS/EC2) ---
resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.workload.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(local.default_tags, {
    Name = "${local.name}-private-${var.availability_zones[count.index]}"
    Tier = "private"
    Note = "LBB application tier - ECS Fargate or EC2"
  })
}

# --- Isolated subnets (LBB PostgreSQL RDS — zero internet) ---
resource "aws_subnet" "isolated" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.workload.id
  cidr_block        = var.isolated_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(local.default_tags, {
    Name = "${local.name}-isolated-${var.availability_zones[count.index]}"
    Tier = "isolated"
    Note = "LBB database tier - RDS PostgreSQL - NO internet route"
  })
}

# --- Internet Gateway (for ALB public subnets) ---
resource "aws_internet_gateway" "workload" {
  count  = var.enable_internet_gateway ? 1 : 0
  vpc_id = aws_vpc.workload.id

  tags = merge(local.default_tags, {
    Name = "${local.name}-igw"
  })
}

# --- NAT Gateway (for private subnet internet access) ---
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = merge(local.default_tags, {
    Name = "${local.name}-nat-eip"
  })
}

resource "aws_nat_gateway" "workload" {
  count         = var.enable_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = var.enable_public_subnets ? aws_subnet.public[0].id : aws_subnet.private[0].id

  tags = merge(local.default_tags, {
    Name = "${local.name}-nat-gw"
  })
}

# --- Route tables ---
resource "aws_route_table" "public" {
  count  = var.enable_public_subnets ? 1 : 0
  vpc_id = aws_vpc.workload.id

  tags = merge(local.default_tags, {
    Name = "${local.name}-public-rt"
    Tier = "public"
  })
}

resource "aws_route" "public_internet" {
  count                  = var.enable_public_subnets && var.enable_internet_gateway ? 1 : 0
  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.workload[0].id
}

resource "aws_route_table_association" "public" {
  count          = var.enable_public_subnets ? length(var.availability_zones) : 0
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.workload.id

  tags = merge(local.default_tags, {
    Name = "${local.name}-private-rt"
    Tier = "private"
  })
}

resource "aws_route" "private_nat" {
  count                  = var.enable_nat_gateway ? 1 : 0
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.workload[0].id
}

resource "aws_route" "private_tgw" {
  count                  = var.enable_transit_gateway && var.transit_gateway_id != "" ? 1 : 0
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = var.transit_gateway_id
}

resource "aws_route_table_association" "private" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table" "isolated" {
  vpc_id = aws_vpc.workload.id

  tags = merge(local.default_tags, {
    Name = "${local.name}-isolated-rt"
    Tier = "isolated"
    Note = "NO default route - LBB database cannot reach internet"
  })
}

resource "aws_route_table_association" "isolated" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.isolated[count.index].id
  route_table_id = aws_route_table.isolated.id
}

# --- Transit Gateway attachment ---
resource "aws_ec2_transit_gateway_vpc_attachment" "workload" {
  count              = var.enable_transit_gateway && var.transit_gateway_id != "" ? 1 : 0
  subnet_ids         = aws_subnet.private[*].id
  transit_gateway_id = var.transit_gateway_id
  vpc_id             = aws_vpc.workload.id

  tags = merge(local.default_tags, {
    Name = "${local.name}-tgw-attachment"
  })
}

# ═══════════════════════════════════════════════════════════
# SECURITY GROUPS — baseline for LBB Scheduler
# ═══════════════════════════════════════════════════════════

# ALB Security Group — public-facing
resource "aws_security_group" "alb" {
  count       = var.enable_public_subnets ? 1 : 0
  name        = "${local.name}-alb-sg"
  description = "LBB Scheduler ALB - allows HTTPS from internet"
  vpc_id      = aws_vpc.workload.id

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "To LBB backend"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(local.default_tags, {
    Name = "${local.name}-alb-sg"
    Tier = "public"
  })
}

# Application Security Group — LBB FastAPI backend
resource "aws_security_group" "app" {
  name        = "${local.name}-app-sg"
  description = "LBB Scheduler application tier - FastAPI backend"
  vpc_id      = aws_vpc.workload.id

  ingress {
    description     = "From ALB only"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = var.enable_public_subnets ? [aws_security_group.alb[0].id] : []
    cidr_blocks     = var.enable_public_subnets ? [] : [var.vpc_cidr]
  }

  egress {
    description = "To database + AWS services"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.default_tags, {
    Name = "${local.name}-app-sg"
    Tier = "private"
  })
}

# Database Security Group — LBB PostgreSQL RDS
resource "aws_security_group" "db" {
  name        = "${local.name}-db-sg"
  description = "LBB Scheduler database tier - PostgreSQL RDS"
  vpc_id      = aws_vpc.workload.id

  ingress {
    description     = "PostgreSQL from app tier only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    description = "No outbound needed"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = []
  }

  tags = merge(local.default_tags, {
    Name = "${local.name}-db-sg"
    Tier = "isolated"
    Note = "Only accepts connections from LBB app tier on port 5432"
  })
}

# ═══════════════════════════════════════════════════════════
# SECURITY HARDENING — account-level defaults
# ═══════════════════════════════════════════════════════════

# IMDSv2 enforcement — prevent Capital One style SSRF attacks
resource "aws_ec2_instance_metadata_defaults" "imdsv2" {
  count                       = var.enforce_imdsv2 ? 1 : 0
  http_tokens                 = "required"
  http_put_response_hop_limit = 1
}

# EBS encryption by default
resource "aws_ebs_encryption_by_default" "enabled" {
  count   = var.enable_ebs_encryption ? 1 : 0
  enabled = true
}

# S3 Block Public Access — account level
resource "aws_s3_account_public_access_block" "block" {
  count                   = var.enable_s3_block_public ? 1 : 0
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ═══════════════════════════════════════════════════════════
# KMS — workload encryption key
# ═══════════════════════════════════════════════════════════

resource "aws_kms_key" "workload" {
  count                   = var.create_workload_kms_key ? 1 : 0
  description             = "${local.name} workload encryption key - LBB Scheduler data"
  deletion_window_in_days = 30
  enable_key_rotation     = var.kms_key_rotation

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableRootAccess"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${local.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowSecurityToolingDecrypt"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${var.security_tooling_account_id}:root" }
        Action    = ["kms:Decrypt", "kms:DescribeKey"]
        Resource  = "*"
      }
    ]
  })

  tags = merge(local.default_tags, {
    Name    = "${local.name}-kms"
    Purpose = "Encrypts LBB Scheduler data at rest"
  })
}

resource "aws_kms_alias" "workload" {
  count         = var.create_workload_kms_key ? 1 : 0
  name          = "alias/${local.name}"
  target_key_id = aws_kms_key.workload[0].key_id
}

# ═══════════════════════════════════════════════════════════
# VPC FLOW LOGS — network visibility
# ═══════════════════════════════════════════════════════════

resource "aws_flow_log" "workload" {
  count           = var.enable_flow_logs ? 1 : 0
  vpc_id          = aws_vpc.workload.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_log[0].arn
  log_destination = aws_cloudwatch_log_group.flow_log[0].arn

  tags = merge(local.default_tags, {
    Name = "${local.name}-vpc-flow-logs"
  })
}

resource "aws_cloudwatch_log_group" "flow_log" {
  count             = var.enable_flow_logs ? 1 : 0
  name              = "/aws/vpc/flowlogs/${local.name}"
  retention_in_days = var.flow_log_retention_days

  tags = merge(local.default_tags, {
    Name = "${local.name}-flow-logs"
  })
}

resource "aws_iam_role" "flow_log" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "${local.name}-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(local.default_tags, { Name = "${local.name}-flow-log-role" })
}

resource "aws_iam_role_policy" "flow_log" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "${local.name}-flow-log-policy"
  role  = aws_iam_role.flow_log[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams"]
      Resource = "*"
    }]
  })
}

# ═══════════════════════════════════════════════════════════
# VPC ENDPOINTS — PrivateLink for AWS services
# LBB accesses AWS APIs without internet
# ═══════════════════════════════════════════════════════════

# S3 Gateway endpoint (free — no per-hour charge)
resource "aws_vpc_endpoint" "s3" {
  count             = var.enable_vpc_endpoints ? 1 : 0
  vpc_id            = aws_vpc.workload.id
  service_name      = "com.amazonaws.${local.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = compact([
    aws_route_table.private.id,
    aws_route_table.isolated.id
  ])

  tags = merge(local.default_tags, {
    Name = "${local.name}-s3-endpoint"
  })
}

# Interface endpoints (cost: ~$7/month each)
resource "aws_security_group" "vpc_endpoints" {
  count       = var.enable_vpc_endpoints ? 1 : 0
  name        = "${local.name}-vpce-sg"
  description = "Security group for VPC interface endpoints"
  vpc_id      = aws_vpc.workload.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(local.default_tags, {
    Name = "${local.name}-vpce-sg"
  })
}

resource "aws_vpc_endpoint" "interface" {
  for_each            = var.enable_vpc_endpoints ? toset([for s in var.vpc_endpoint_services : s if s != "s3"]) : toset([])
  vpc_id              = aws_vpc.workload.id
  service_name        = "com.amazonaws.${local.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(local.default_tags, {
    Name    = "${local.name}-${each.value}-endpoint"
    Service = each.value
  })
}

# ═══════════════════════════════════════════════════════════
# IAM ACCESS ANALYZER
# ═══════════════════════════════════════════════════════════

resource "aws_accessanalyzer_analyzer" "workload" {
  count         = var.enable_iam_access_analyzer ? 1 : 0
  analyzer_name = "${local.name}-access-analyzer"
  type          = "ACCOUNT"

  tags = merge(local.default_tags, {
    Name = "${local.name}-access-analyzer"
  })
}

resource "aws_accessanalyzer_analyzer" "unused_access" {
  count         = var.enable_iam_access_analyzer_unused ? 1 : 0
  analyzer_name = "${local.name}-unused-access-analyzer"
  type          = "ACCOUNT"

  configuration {
    unused_access {
      unused_access_age = 90
    }
  }

  tags = merge(local.default_tags, {
    Name = "${local.name}-unused-access-analyzer"
  })
}

# ═══════════════════════════════════════════════════════════
# PERMISSION BOUNDARY — prevents privilege escalation
# ═══════════════════════════════════════════════════════════

resource "aws_iam_policy" "permission_boundary" {
  count = var.enable_permission_boundaries && var.permission_boundary_policy_arn == "" ? 1 : 0
  name  = "${local.name}-permission-boundary"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowMostActions"
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      },
      {
        Sid    = "DenyEscalation"
        Effect = "Deny"
        Action = [
          "iam:CreateUser",
          "iam:CreateRole",
          "iam:DeleteRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePermissionsBoundary",
          "organizations:*",
          "account:*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.default_tags, {
    Name = "${local.name}-permission-boundary"
  })
}

# ═══════════════════════════════════════════════════════════
# SECRETS MANAGER — LBB database credentials
# ═══════════════════════════════════════════════════════════

resource "aws_secretsmanager_secret" "lbb_db_password" {
  count = var.enable_secrets_manager && var.enable_lbb_scheduler ? 1 : 0
  name  = "${local.name}/lbb/database-password"

  tags = merge(local.default_tags, {
    Name    = "${local.name}-lbb-db-password"
    Purpose = "LBB Scheduler PostgreSQL password"
  })
}

resource "aws_secretsmanager_secret" "lbb_jwt_secret" {
  count = var.enable_secrets_manager && var.enable_lbb_scheduler ? 1 : 0
  name  = "${local.name}/lbb/jwt-signing-key"

  tags = merge(local.default_tags, {
    Name    = "${local.name}-lbb-jwt-key"
    Purpose = "LBB Scheduler JWT signing key"
  })
}

resource "aws_secretsmanager_secret" "lbb_api_key" {
  count = var.enable_secrets_manager && var.enable_lbb_scheduler ? 1 : 0
  name  = "${local.name}/lbb/api-key"

  tags = merge(local.default_tags, {
    Name    = "${local.name}-lbb-api-key"
    Purpose = "LBB Scheduler external API key"
  })
}

# ═══════════════════════════════════════════════════════════
# INSPECTOR — vulnerability scanning for LBB
# ═══════════════════════════════════════════════════════════

resource "aws_inspector2_enabler" "workload" {
  count       = var.enable_inspector ? 1 : 0
  account_ids = [local.account_id]
  resource_types = compact([
    var.enable_inspector_ec2 ? "EC2" : "",
    var.enable_inspector_ecr ? "ECR" : "",
    var.enable_inspector_lambda ? "LAMBDA" : "",
  ])
}

# ═══════════════════════════════════════════════════════════
# WAF — web application firewall for LBB
# ═══════════════════════════════════════════════════════════

resource "aws_wafv2_web_acl" "lbb" {
  count       = var.enable_waf ? 1 : 0
  name        = "${local.name}-lbb-waf"
  description = "WAF protecting LBB Scheduler ALB/API Gateway"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  dynamic "rule" {
    for_each = var.waf_managed_rules
    content {
      name     = rule.value
      priority = rule.key + 1

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = rule.value
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.value
        sampled_requests_enabled   = true
      }
    }
  }

  # Rate limiting — prevent brute force against LBB login
  rule {
    name     = "rate-limit"
    priority = 100

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name}-lbb-waf"
    sampled_requests_enabled   = true
  }

  tags = merge(local.default_tags, {
    Name    = "${local.name}-lbb-waf"
    Purpose = "Protects LBB from SQL injection, XSS, and bot attacks"
  })
}

# ═══════════════════════════════════════════════════════════
# WIZ SCANNER ROLE — CNAPP agentless scanning
# ═══════════════════════════════════════════════════════════

resource "aws_iam_role" "wiz_scanner" {
  count = var.enable_wiz_scanning ? 1 : 0
  name  = "WizScanner"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowWizScanning"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${var.wiz_aws_account_id}:root" }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "sts:ExternalId" = var.wiz_external_id } }
    }]
  })

  tags = merge(local.default_tags, {
    Name    = "WizScanner"
    Purpose = "Wiz CNAPP scanning of LBB infrastructure"
  })
}

resource "aws_iam_role_policy_attachment" "wiz_security_audit" {
  count      = var.enable_wiz_scanning ? 1 : 0
  role       = aws_iam_role.wiz_scanner[0].name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "aws_iam_role_policy_attachment" "wiz_readonly" {
  count      = var.enable_wiz_scanning ? 1 : 0
  role       = aws_iam_role.wiz_scanner[0].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# ═══════════════════════════════════════════════════════════
# BUDGETS — cost monitoring for LBB account
# ═══════════════════════════════════════════════════════════

resource "aws_budgets_budget" "workload" {
  count       = var.enable_budgets ? 1 : 0
  name        = "${local.name}-monthly-budget"
  budget_type = "COST"
  time_unit   = "MONTHLY"

  limit_amount = tostring(var.monthly_budget_amount)
  limit_unit   = "USD"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }

  tags = merge(local.default_tags, {
    Name = "${local.name}-budget"
  })
}

# ═══════════════════════════════════════════════════════════
# SNS — security alerting for this account
# ═══════════════════════════════════════════════════════════

resource "aws_sns_topic" "security_alerts" {
  name = "${local.name}-security-alerts"

  tags = merge(local.default_tags, {
    Name    = "${local.name}-security-alerts"
    Purpose = "Security alerts for LBB ${var.account_name} account"
  })
}

resource "aws_sns_topic_subscription" "security_email" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.security_alert_email
}

# ═══════════════════════════════════════════════════════════
# CLOUDWATCH ALARMS — baseline monitoring
# ═══════════════════════════════════════════════════════════

# Alarm: unauthorized API calls in this account
resource "aws_cloudwatch_metric_alarm" "unauthorized_api" {
  alarm_name          = "${local.name}-unauthorized-api-calls"
  alarm_description   = "Unauthorized API calls detected in LBB ${var.account_name} account"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnauthorizedAttemptCount"
  namespace           = "CloudTrailMetrics"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.security_alerts.arn]

  tags = merge(local.default_tags, {
    Name     = "${local.name}-unauthorized-api"
    Severity = "HIGH"
  })
}

# Alarm: console login without MFA
resource "aws_cloudwatch_metric_alarm" "console_no_mfa" {
  alarm_name          = "${local.name}-console-login-no-mfa"
  alarm_description   = "Console login without MFA in LBB ${var.account_name} account"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ConsoleSignInWithoutMfa"
  namespace           = "CloudTrailMetrics"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.security_alerts.arn]

  tags = merge(local.default_tags, {
    Name     = "${local.name}-console-no-mfa"
    Severity = "CRITICAL"
  })
}