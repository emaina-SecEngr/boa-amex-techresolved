# ============================================================
# main.tf — AI Security Agent
# Module: ai-security-agent
#
# DEPLOYMENT ACCOUNT: Security Tooling (368351959735)
# PREREQUISITE: guardduty, security-hub, soar modules complete
#
# ARCHITECTURE:
#   EventBridge rules (GuardDuty / Security Hub findings)
#   → normalize finding into a flat payload (same shape SOAR's
#     own rules already use)
#   → triage Lambda calls Bedrock for a triage summary +
#     recommended playbook
#   → if enable_autonomous_response AND the recommended
#     playbook is in allowed_playbooks, invoke the SOAR
#     dispatcher directly (lambda:InvokeFunction) with that
#     playbook
#   → every decision, taken or not, is published to SNS and
#     logged to CloudWatch for audit
#
# KNOWN PREREQUISITE GAP:
# Bedrock model access must be requested/approved in the AWS
# Console per-account before InvokeModel calls succeed for a
# given model — a one-time AWS-side step Terraform can't
# automate. This module deploys successfully regardless; the
# Lambda will error on invocation until that's done.
# ============================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id     = data.aws_caller_identity.current.account_id
  region         = data.aws_region.current.name
  bedrock_region = var.bedrock_region != "" ? var.bedrock_region : var.aws_region

  # lambda:InvokeFunction on the SOAR dispatcher is only granted
  # once a real dispatcher ARN is wired in — keeps the IAM policy
  # valid (a Resource can't be an empty string) when the module is
  # used standalone without SOAR present.
  soar_invoke_statement = var.soar_dispatcher_arn != "" ? [{
    Sid      = "InvokeSOARDispatcher"
    Effect   = "Allow"
    Action   = "lambda:InvokeFunction"
    Resource = var.soar_dispatcher_arn
  }] : []
}

# -----------------------------------------------------------
# IAM ROLE — dedicated to this agent, not shared with SOAR
# -----------------------------------------------------------
resource "aws_iam_role" "ai_security_agent" {
  count = var.enable_ai_security_agent ? 1 : 0
  name  = "${var.project_prefix}-ai-security-agent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-ai-security-agent-role"
    Purpose = "AI Security Agent - Bedrock triage + authorized SOAR invocation"
  })
}

resource "aws_iam_role_policy" "ai_security_agent" {
  count = var.enable_ai_security_agent ? 1 : 0
  name  = "${var.project_prefix}-ai-security-agent-policy"
  role  = aws_iam_role.ai_security_agent[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Sid      = "BedrockInvoke"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
        Resource = "arn:aws:bedrock:${local.bedrock_region}::foundation-model/${var.bedrock_model_id}"
      },
      {
        Sid    = "GuardDutyRead"
        Effect = "Allow"
        Action = [
          "guardduty:GetFindings",
          "guardduty:GetDetector",
          "guardduty:ListFindings"
        ]
        Resource = "*"
      },
      {
        Sid    = "SecurityHubRead"
        Effect = "Allow"
        Action = [
          "securityhub:BatchGetFindings",
          "securityhub:GetFindings"
        ]
        Resource = "*"
      },
      {
        Sid      = "SNSPublish"
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = "arn:aws:sns:${local.region}:${local.account_id}:${var.project_prefix}-ai-security-agent-alerts"
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
      }
    ], local.soar_invoke_statement)
  })
}

# -----------------------------------------------------------
# SNS TOPIC — every triage decision, taken or not
# -----------------------------------------------------------
resource "aws_sns_topic" "ai_agent_alerts" {
  count = var.enable_ai_security_agent ? 1 : 0
  name  = "${var.project_prefix}-ai-security-agent-alerts"

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-ai-security-agent-alerts"
    Purpose = "Every AI Security Agent triage decision and SOAR invocation, successful or not"
  })
}

resource "aws_sns_topic_subscription" "ai_agent_alerts_email" {
  count     = var.enable_ai_security_agent ? 1 : 0
  topic_arn = aws_sns_topic.ai_agent_alerts[0].arn
  protocol  = "email"
  endpoint  = var.security_alert_email
}

# -----------------------------------------------------------
# LAMBDA — triage agent
# -----------------------------------------------------------
data "archive_file" "triage_agent" {
  count       = var.enable_ai_security_agent ? 1 : 0
  type        = "zip"
  source_file = "${path.module}/triage_agent.py"
  output_path = "${path.module}/triage_agent.zip"
}

resource "aws_lambda_function" "triage_agent" {
  count            = var.enable_ai_security_agent ? 1 : 0
  filename         = data.archive_file.triage_agent[0].output_path
  source_code_hash = data.archive_file.triage_agent[0].output_base64sha256
  function_name    = "${var.project_prefix}-ai-security-agent"
  role             = aws_iam_role.ai_security_agent[0].arn
  handler          = "triage_agent.lambda_handler"
  runtime          = "python3.12"
  timeout          = 60
  memory_size      = 256

  environment {
    variables = {
      BEDROCK_MODEL_ID           = var.bedrock_model_id
      BEDROCK_REGION             = local.bedrock_region
      SOAR_DISPATCHER_ARN        = var.soar_dispatcher_arn
      ALLOWED_PLAYBOOKS          = jsonencode(var.allowed_playbooks)
      SOAR_PLAYBOOK_CATALOG      = jsonencode(var.soar_playbook_catalog)
      ENABLE_AUTONOMOUS_RESPONSE = tostring(var.enable_autonomous_response)
      TRIAGE_SNS_TOPIC_ARN       = aws_sns_topic.ai_agent_alerts[0].arn
    }
  }

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-ai-security-agent"
    Purpose = "Bedrock-backed finding triage + authorized SOAR invocation"
  })
}

resource "aws_cloudwatch_log_group" "triage_agent" {
  count             = var.enable_ai_security_agent ? 1 : 0
  name              = "/aws/lambda/${var.project_prefix}-ai-security-agent"
  retention_in_days = var.log_retention_days

  tags = merge(var.common_tags, {
    Name = "${var.project_prefix}-ai-security-agent-logs"
  })
}

# -----------------------------------------------------------
# EVENTBRIDGE RULES — route findings to the triage agent
# Both rules normalize into the same flat payload shape the
# Lambda (and SOAR's own dispatcher) expect: {source,
# finding_type, severity, account_id, region, resource_arn,
# finding_id}.
# -----------------------------------------------------------
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  count       = var.enable_ai_security_agent ? 1 : 0
  name        = "${var.project_prefix}-ai-agent-guardduty-findings"
  description = "Routes GuardDuty findings at or above triage_severity_threshold to the AI Security Agent"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", var.triage_severity_threshold] }]
    }
  })

  tags = merge(var.common_tags, { Name = "${var.project_prefix}-ai-agent-guardduty-findings" })
}

resource "aws_cloudwatch_event_target" "guardduty_findings" {
  count     = var.enable_ai_security_agent ? 1 : 0
  rule      = aws_cloudwatch_event_rule.guardduty_findings[0].name
  target_id = "AISecurityAgent"
  arn       = aws_lambda_function.triage_agent[0].arn

  input_transformer {
    input_paths = {
      finding_type = "$.detail.type"
      severity     = "$.detail.severity"
      account_id   = "$.detail.accountId"
      region       = "$.region"
      resource_arn = "$.detail.resource.instanceDetails.instanceId"
      finding_id   = "$.detail.id"
    }
    input_template = <<-EOT
      {
        "source": "guardduty",
        "finding_type": <finding_type>,
        "severity": <severity>,
        "account_id": <account_id>,
        "region": <region>,
        "resource_arn": <resource_arn>,
        "finding_id": <finding_id>
      }
    EOT
  }
}

resource "aws_lambda_permission" "guardduty_findings" {
  count         = var.enable_ai_security_agent ? 1 : 0
  statement_id  = "AllowGuardDutyFindings"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.triage_agent[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.guardduty_findings[0].arn
}

# Security Hub's Severity.Label enum (LOW/MEDIUM/HIGH/CRITICAL) has no
# direct numeric equivalent to triage_severity_threshold — MEDIUM and
# up is the closest analog to a 0-10 threshold around 4.
resource "aws_cloudwatch_event_rule" "securityhub_findings" {
  count       = var.enable_ai_security_agent ? 1 : 0
  name        = "${var.project_prefix}-ai-agent-securityhub-findings"
  description = "Routes Security Hub MEDIUM+ findings to the AI Security Agent"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity = { Label = ["MEDIUM", "HIGH", "CRITICAL"] }
        Workflow = { Status = ["NEW"] }
      }
    }
  })

  tags = merge(var.common_tags, { Name = "${var.project_prefix}-ai-agent-securityhub-findings" })
}

resource "aws_cloudwatch_event_target" "securityhub_findings" {
  count     = var.enable_ai_security_agent ? 1 : 0
  rule      = aws_cloudwatch_event_rule.securityhub_findings[0].name
  target_id = "AISecurityAgentSecurityHub"
  arn       = aws_lambda_function.triage_agent[0].arn

  # Findings arrive as an array (detail.findings[]) - indexing [0]
  # covers the common single-finding-per-event case, same
  # simplification modules/soar makes for its own SecurityHub rule.
  input_transformer {
    input_paths = {
      finding_type = "$.detail.findings[0].Title"
      severity     = "$.detail.findings[0].Severity.Normalized"
      account_id   = "$.detail.findings[0].AwsAccountId"
      resource_arn = "$.detail.findings[0].Resources[0].Id"
      finding_id   = "$.detail.findings[0].Id"
    }
    input_template = <<-EOT
      {
        "source": "securityhub",
        "finding_type": <finding_type>,
        "severity": <severity>,
        "account_id": <account_id>,
        "region": "",
        "resource_arn": <resource_arn>,
        "finding_id": <finding_id>
      }
    EOT
  }
}

resource "aws_lambda_permission" "securityhub_findings" {
  count         = var.enable_ai_security_agent ? 1 : 0
  statement_id  = "AllowSecurityHubFindings"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.triage_agent[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.securityhub_findings[0].arn
}
