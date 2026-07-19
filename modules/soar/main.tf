# ============================================================
# main.tf — SOAR playbooks (40 automated response actions)
# Module: soar
#
# DEPLOYMENT ACCOUNT: Security Tooling (368351959735)
# PREREQUISITE: guardduty, security-hub modules complete
#
# ARCHITECTURE:
#   EventBridge rules match finding types
#   → Step Functions orchestrate multi-step response
#   → Lambda playbooks execute actions
#   → SNS notifies security team
#   → CloudTrail logs every action for audit trail
#
# COST: ~$0 (Lambda + EventBridge + SNS free tier)
# ============================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id       = data.aws_caller_identity.current.account_id
  region           = data.aws_region.current.name
  enable_infra     = var.enable_soar && var.enable_infrastructure_playbooks
  enable_iam       = var.enable_soar && var.enable_iam_playbooks
  enable_token     = var.enable_soar && var.enable_token_playbooks
  enable_container = var.enable_soar && var.enable_container_playbooks
  enable_network   = var.enable_soar && var.enable_network_playbooks
  enable_runtime   = var.enable_soar && var.enable_runtime_playbooks
  enable_vuln      = var.enable_soar && var.enable_vulnerability_playbooks
  enable_exfil     = var.enable_soar && var.enable_data_exfiltration_playbooks
}

# -----------------------------------------------------------
# SOAR EXECUTION IAM ROLE
# Single role for all playbooks — broad permissions needed
# to respond to incidents across multiple AWS services
# -----------------------------------------------------------
resource "aws_iam_role" "soar_execution" {
  count = var.enable_soar ? 1 : 0
  name  = "${var.project_prefix}-soar-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-soar-execution-role"
    Purpose = "SOAR playbook execution - automated incident response"
  })
}

resource "aws_iam_role_policy" "soar_execution" {
  count = var.enable_soar ? 1 : 0
  name  = "${var.project_prefix}-soar-execution-policy"
  role  = aws_iam_role.soar_execution[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2Response"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:ModifyInstanceAttribute",
          "ec2:CreateSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateSnapshot",
          "ec2:CreateSnapshots",
          "ec2:DescribeSnapshots",
          "ec2:DescribeVolumes",
          "ec2:ModifyInstanceMetadataOptions",
          "ec2:DescribeNetworkAcls",
          "ec2:CreateNetworkAclEntry",
          "ec2:ReplaceNetworkAclEntry"
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMResponse"
        Effect = "Allow"
        Action = [
          "iam:ListAccessKeys",
          "iam:UpdateAccessKey",
          "iam:DeleteAccessKey",
          "iam:GetAccessKeyLastUsed",
          "iam:PutUserPolicy",
          "iam:DeleteUserPolicy",
          "iam:GetUserPolicy",
          "iam:ListUserPolicies",
          "iam:AttachUserPolicy",
          "iam:DetachUserPolicy",
          "iam:ListAttachedUserPolicies",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:UpdateAssumeRolePolicy",
          "iam:GetRole",
          "iam:ListRoles",
          "iam:GetUser",
          "iam:ListUsers",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
          "iam:CreatePolicyVersion",
          "iam:DeleteLoginProfile",
          "iam:PutRolePermissionsBoundary"
        ]
        Resource = "*"
      },
      {
        Sid    = "STSResponse"
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity",
          "sts:GetAccessKeyInfo"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3Response"
        Effect = "Allow"
        Action = [
          "s3:GetBucketPolicy",
          "s3:PutBucketPolicy",
          "s3:GetBucketAcl",
          "s3:PutBucketAcl",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock",
          "s3:PutObject"
        ]
        Resource = "*"
      },
      {
        Sid    = "SecretsResponse"
        Effect = "Allow"
        Action = [
          "secretsmanager:RotateSecret",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets",
          "secretsmanager:GetSecretValue",
          "secretsmanager:UpdateSecret"
        ]
        Resource = "*"
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
        Sid    = "SecurityHubUpdate"
        Effect = "Allow"
        Action = [
          "securityhub:BatchUpdateFindings",
          "securityhub:GetFindings"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudTrailRead"
        Effect = "Allow"
        Action = [
          "cloudtrail:LookupEvents"
        ]
        Resource = "*"
      },
      {
        Sid    = "SNSPublish"
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = "arn:aws:sns:${local.region}:${local.account_id}:${var.project_prefix}-*"
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
        Sid    = "WAFResponse"
        Effect = "Allow"
        Action = [
          "wafv2:GetIPSet",
          "wafv2:UpdateIPSet",
          "wafv2:ListIPSets"
        ]
        Resource = "*"
      },
      {
        Sid    = "NetworkFirewallResponse"
        Effect = "Allow"
        Action = [
          "network-firewall:UpdateRuleGroup",
          "network-firewall:DescribeRuleGroup",
          "network-firewall:ListRuleGroups"
        ]
        Resource = "*"
      },
      {
        Sid    = "Route53Response"
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:GetHostedZone",
          "route53:ListResourceRecordSets"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------
# SNS TOPICS FOR SOAR NOTIFICATIONS
# -----------------------------------------------------------
resource "aws_sns_topic" "soar_alerts" {
  count = var.enable_soar ? 1 : 0
  name  = "${var.project_prefix}-soar-alerts"

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-soar-alerts"
    Purpose = "SOAR playbook execution notifications"
  })
}

resource "aws_sns_topic_subscription" "soar_email" {
  count     = var.enable_soar ? 1 : 0
  topic_arn = aws_sns_topic.soar_alerts[0].arn
  protocol  = "email"
  endpoint  = var.security_alert_email
}

resource "aws_sns_topic" "soar_critical" {
  count = var.enable_soar ? 1 : 0
  name  = "${var.project_prefix}-soar-critical"

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-soar-critical"
    Purpose = "CRITICAL SOAR alerts - container escape / root lockdown / data exfil"
  })
}

resource "aws_sns_topic_subscription" "soar_critical_email" {
  count     = var.enable_soar ? 1 : 0
  topic_arn = aws_sns_topic.soar_critical[0].arn
  protocol  = "email"
  endpoint  = var.critical_alert_email
}

resource "aws_sns_topic_policy" "soar_alerts" {
  count = var.enable_soar ? 1 : 0
  arn   = aws_sns_topic.soar_alerts[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowEventsAndLambda"
      Effect    = "Allow"
      Principal = { Service = ["events.amazonaws.com", "lambda.amazonaws.com"] }
      Action    = "sns:Publish"
      Resource  = aws_sns_topic.soar_alerts[0].arn
    }]
  })
}

# -----------------------------------------------------------
# QUARANTINE SECURITY GROUP
# Denies ALL traffic — used by ec2-isolate playbook
# -----------------------------------------------------------
resource "aws_security_group" "quarantine" {
  count       = local.enable_infra && var.quarantine_vpc_id != "" ? 1 : 0
  name        = var.quarantine_sg_name
  description = "SOAR quarantine - denies ALL traffic. Applied to compromised EC2 instances."
  vpc_id      = var.quarantine_vpc_id

  tags = merge(var.common_tags, {
    Name    = var.quarantine_sg_name
    Purpose = "SOAR quarantine - zero network access"
  })
}

# -----------------------------------------------------------
# FORENSICS S3 BUCKET
# Evidence preservation separate from log archive
# -----------------------------------------------------------
resource "aws_s3_bucket" "forensics" {
  count  = var.enable_soar && var.forensics_bucket_name != "" ? 1 : 0
  bucket = var.forensics_bucket_name

  tags = merge(var.common_tags, {
    Name    = var.forensics_bucket_name
    Purpose = "SOAR forensic evidence - EBS snapshots, memory dumps, pod logs"
  })
}

resource "aws_s3_bucket_versioning" "forensics" {
  count  = var.enable_soar && var.forensics_bucket_name != "" ? 1 : 0
  bucket = aws_s3_bucket.forensics[0].id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_public_access_block" "forensics" {
  count                   = var.enable_soar && var.forensics_bucket_name != "" ? 1 : 0
  bucket                  = aws_s3_bucket.forensics[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------
# LAMBDA DEPLOYMENT PACKAGE
# Single Lambda with handler routing to each playbook
# -----------------------------------------------------------
resource "aws_lambda_function" "soar_dispatcher" {
  count         = var.enable_soar ? 1 : 0
  filename      = "${path.module}/soar_playbooks.zip"
  function_name = "${var.project_prefix}-soar-dispatcher"
  role          = aws_iam_role.soar_execution[0].arn
  handler       = "soar_playbooks.lambda_handler"
  runtime       = "python3.12"
  timeout       = 300
  memory_size   = 512

  environment {
    variables = {
      PROJECT_PREFIX         = var.project_prefix
      REGION                 = local.region
      ACCOUNT_ID             = local.account_id
      SNS_TOPIC_ARN          = aws_sns_topic.soar_alerts[0].arn
      SNS_CRITICAL_TOPIC_ARN = aws_sns_topic.soar_critical[0].arn
      QUARANTINE_SG_ID       = var.quarantine_vpc_id != "" && length(aws_security_group.quarantine) > 0 ? aws_security_group.quarantine[0].id : ""
      FORENSICS_BUCKET       = var.forensics_bucket_name
      RESPONSE_MODE          = var.response_mode
      LOG_ARCHIVE_BUCKET     = var.log_archive_bucket_name
      GUARDDUTY_DETECTOR_ID  = var.guardduty_detector_id
    }
  }

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-soar-dispatcher"
    Purpose = "SOAR playbook dispatcher - routes findings to correct response"
  })
}

resource "aws_cloudwatch_log_group" "soar_dispatcher" {
  count             = var.enable_soar ? 1 : 0
  name              = "/aws/lambda/${var.project_prefix}-soar-dispatcher"
  retention_in_days = 90

  tags = merge(var.common_tags, {
    Name = "${var.project_prefix}-soar-dispatcher-logs"
  })
}

# -----------------------------------------------------------
# EVENTBRIDGE RULES — route findings to SOAR dispatcher
# Each rule matches a specific finding type and invokes
# the dispatcher with the playbook name as input
# -----------------------------------------------------------

# Rule 1: GuardDuty HIGH severity — infrastructure response
resource "aws_cloudwatch_event_rule" "guardduty_high" {
  count       = local.enable_infra ? 1 : 0
  name        = "${var.project_prefix}-soar-guardduty-high"
  description = "Routes high severity GuardDuty findings to SOAR dispatcher"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 7] }]
    }
  })

  tags = merge(var.common_tags, { Name = "${var.project_prefix}-soar-guardduty-high" })
}

resource "aws_cloudwatch_event_target" "guardduty_high" {
  count     = local.enable_infra ? 1 : 0
  rule      = aws_cloudwatch_event_rule.guardduty_high[0].name
  target_id = "SOARDispatcher"
  arn       = aws_lambda_function.soar_dispatcher[0].arn

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
        "playbook": "auto-route",
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

# Rule 2: IAM credential compromise
resource "aws_cloudwatch_event_rule" "iam_compromise" {
  count       = local.enable_iam ? 1 : 0
  name        = "${var.project_prefix}-soar-iam-compromise"
  description = "Routes IAM credential compromise findings to SOAR"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      type = [
        { prefix = "UnauthorizedAccess:IAMUser" },
        { prefix = "CredentialAccess" },
        { prefix = "Persistence:IAMUser" }
      ]
    }
  })

  tags = merge(var.common_tags, { Name = "${var.project_prefix}-soar-iam-compromise" })
}

resource "aws_cloudwatch_event_target" "iam_compromise" {
  count     = local.enable_iam ? 1 : 0
  rule      = aws_cloudwatch_event_rule.iam_compromise[0].name
  target_id = "SOARDispatcherIAM"
  arn       = aws_lambda_function.soar_dispatcher[0].arn

  input_transformer {
    input_paths = {
      finding_type = "$.detail.type"
      severity     = "$.detail.severity"
      account_id   = "$.detail.accountId"
      resource_arn = "$.detail.resource.accessKeyDetails.userName"
      finding_id   = "$.detail.id"
    }
    input_template = <<-EOT
      {
        "playbook": "iam-response",
        "source": "guardduty",
        "finding_type": <finding_type>,
        "severity": <severity>,
        "account_id": <account_id>,
        "resource_arn": <resource_arn>,
        "finding_id": <finding_id>
      }
    EOT
  }
}

# Rule 3: Root account usage — immediate lockdown
resource "aws_cloudwatch_event_rule" "root_usage" {
  count       = local.enable_iam ? 1 : 0
  name        = "${var.project_prefix}-soar-root-lockdown"
  description = "Triggers root lockdown playbook on ANY root account usage"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      type = [{ prefix = "Policy:IAMUser/RootCredentialUsage" }]
    }
  })

  tags = merge(var.common_tags, { Name = "${var.project_prefix}-soar-root-lockdown" })
}

resource "aws_cloudwatch_event_target" "root_usage" {
  count     = local.enable_iam ? 1 : 0
  rule      = aws_cloudwatch_event_rule.root_usage[0].name
  target_id = "SOARRootLockdown"
  arn       = aws_lambda_function.soar_dispatcher[0].arn

  input_transformer {
    input_paths = {
      finding_type = "$.detail.type"
      severity     = "$.detail.severity"
      account_id   = "$.detail.accountId"
      finding_id   = "$.detail.id"
    }
    input_template = <<-EOT
      {
        "playbook": "iam-root-lockdown",
        "source": "guardduty",
        "finding_type": <finding_type>,
        "severity": <severity>,
        "account_id": <account_id>,
        "resource_arn": "root",
        "finding_id": <finding_id>
      }
    EOT
  }
}

# Rule 4: Token/credential exfiltration
resource "aws_cloudwatch_event_rule" "token_exfil" {
  count       = local.enable_token ? 1 : 0
  name        = "${var.project_prefix}-soar-token-exfil"
  description = "Routes credential exfiltration findings to SOAR token playbooks"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      type = [
        { prefix = "UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration" },
        { prefix = "UnauthorizedAccess:EC2/MetadataDNSRebind" }
      ]
    }
  })

  tags = merge(var.common_tags, { Name = "${var.project_prefix}-soar-token-exfil" })
}

resource "aws_cloudwatch_event_target" "token_exfil" {
  count     = local.enable_token ? 1 : 0
  rule      = aws_cloudwatch_event_rule.token_exfil[0].name
  target_id = "SOARTokenExfil"
  arn       = aws_lambda_function.soar_dispatcher[0].arn

  input_transformer {
    input_paths = {
      finding_type = "$.detail.type"
      severity     = "$.detail.severity"
      account_id   = "$.detail.accountId"
      resource_arn = "$.detail.resource.instanceDetails.instanceId"
      finding_id   = "$.detail.id"
    }
    input_template = <<-EOT
      {
        "playbook": "token-response",
        "source": "guardduty",
        "finding_type": <finding_type>,
        "severity": <severity>,
        "account_id": <account_id>,
        "resource_arn": <resource_arn>,
        "finding_id": <finding_id>
      }
    EOT
  }
}

# Rule 5: Data exfiltration detection
resource "aws_cloudwatch_event_rule" "data_exfil" {
  count       = local.enable_exfil ? 1 : 0
  name        = "${var.project_prefix}-soar-data-exfil"
  description = "Routes data exfiltration findings to SOAR"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      type = [
        { prefix = "Exfiltration" },
        { prefix = "Trojan:EC2/DNSDataExfiltration" },
        { prefix = "Trojan:EC2/BlackholeTraffic" }
      ]
    }
  })

  tags = merge(var.common_tags, { Name = "${var.project_prefix}-soar-data-exfil" })
}

resource "aws_cloudwatch_event_target" "data_exfil" {
  count     = local.enable_exfil ? 1 : 0
  rule      = aws_cloudwatch_event_rule.data_exfil[0].name
  target_id = "SOARDataExfil"
  arn       = aws_lambda_function.soar_dispatcher[0].arn

  input_transformer {
    input_paths = {
      finding_type = "$.detail.type"
      severity     = "$.detail.severity"
      account_id   = "$.detail.accountId"
      resource_arn = "$.detail.resource.instanceDetails.instanceId"
      finding_id   = "$.detail.id"
    }
    input_template = <<-EOT
      {
        "playbook": "data-exfil-response",
        "source": "guardduty",
        "finding_type": <finding_type>,
        "severity": <severity>,
        "account_id": <account_id>,
        "resource_arn": <resource_arn>,
        "finding_id": <finding_id>
      }
    EOT
  }
}

# Rule 6: Security Hub critical — S3 remediation
resource "aws_cloudwatch_event_rule" "s3_public" {
  count       = local.enable_infra ? 1 : 0
  name        = "${var.project_prefix}-soar-s3-public"
  description = "Auto-remediates publicly accessible S3 buckets"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Title      = [{ prefix = "S3" }]
        Severity   = { Label = ["CRITICAL", "HIGH"] }
        Workflow   = { Status = ["NEW"] }
        Compliance = { Status = ["FAILED"] }
      }
    }
  })

  tags = merge(var.common_tags, { Name = "${var.project_prefix}-soar-s3-public" })
}

resource "aws_cloudwatch_event_target" "s3_public" {
  count     = local.enable_infra ? 1 : 0
  rule      = aws_cloudwatch_event_rule.s3_public[0].name
  target_id = "SOARS3Remediate"
  arn       = aws_lambda_function.soar_dispatcher[0].arn
}

# Rule 7: Network — C2 communication and lateral movement
resource "aws_cloudwatch_event_rule" "network_threat" {
  count       = local.enable_network ? 1 : 0
  name        = "${var.project_prefix}-soar-network-threat"
  description = "Routes C2 and lateral movement findings to SOAR"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      type = [
        { prefix = "Backdoor:EC2" },
        { prefix = "Trojan:EC2" },
        { prefix = "Recon:EC2" },
        { prefix = "CryptoCurrency:EC2" }
      ]
    }
  })

  tags = merge(var.common_tags, { Name = "${var.project_prefix}-soar-network-threat" })
}

resource "aws_cloudwatch_event_target" "network_threat" {
  count     = local.enable_network ? 1 : 0
  rule      = aws_cloudwatch_event_rule.network_threat[0].name
  target_id = "SOARNetworkThreat"
  arn       = aws_lambda_function.soar_dispatcher[0].arn

  input_transformer {
    input_paths = {
      finding_type = "$.detail.type"
      severity     = "$.detail.severity"
      account_id   = "$.detail.accountId"
      resource_arn = "$.detail.resource.instanceDetails.instanceId"
      finding_id   = "$.detail.id"
    }
    input_template = <<-EOT
      {
        "playbook": "network-response",
        "source": "guardduty",
        "finding_type": <finding_type>,
        "severity": <severity>,
        "account_id": <account_id>,
        "resource_arn": <resource_arn>,
        "finding_id": <finding_id>
      }
    EOT
  }
}

# Rule 8: Config change — unauthorized IAM policy change
resource "aws_cloudwatch_event_rule" "config_iam_change" {
  count       = local.enable_iam ? 1 : 0
  name        = "${var.project_prefix}-soar-iam-policy-change"
  description = "Detects unauthorized IAM policy changes for auto-rollback"

  event_pattern = jsonencode({
    source      = ["aws.config"]
    detail-type = ["Config Rules Compliance Change"]
    detail = {
      messageType = ["ComplianceChangeNotification"]
      newEvaluationResult = {
        complianceType = ["NON_COMPLIANT"]
      }
      configRuleName = [
        { prefix = "iam-" },
        { prefix = "restricted-" }
      ]
    }
  })

  tags = merge(var.common_tags, { Name = "${var.project_prefix}-soar-iam-policy-change" })
}

resource "aws_cloudwatch_event_target" "config_iam_change" {
  count     = local.enable_iam ? 1 : 0
  rule      = aws_cloudwatch_event_rule.config_iam_change[0].name
  target_id = "SOARIAMRollback"
  arn       = aws_lambda_function.soar_dispatcher[0].arn
}

# -----------------------------------------------------------
# LAMBDA PERMISSIONS — allow EventBridge to invoke dispatcher
# -----------------------------------------------------------
resource "aws_lambda_permission" "guardduty_high" {
  count         = local.enable_infra ? 1 : 0
  statement_id  = "AllowGuardDutyHigh"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.soar_dispatcher[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.guardduty_high[0].arn
}

resource "aws_lambda_permission" "iam_compromise" {
  count         = local.enable_iam ? 1 : 0
  statement_id  = "AllowIAMCompromise"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.soar_dispatcher[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.iam_compromise[0].arn
}

resource "aws_lambda_permission" "root_usage" {
  count         = local.enable_iam ? 1 : 0
  statement_id  = "AllowRootUsage"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.soar_dispatcher[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.root_usage[0].arn
}

resource "aws_lambda_permission" "token_exfil" {
  count         = local.enable_token ? 1 : 0
  statement_id  = "AllowTokenExfil"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.soar_dispatcher[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.token_exfil[0].arn
}

resource "aws_lambda_permission" "data_exfil" {
  count         = local.enable_exfil ? 1 : 0
  statement_id  = "AllowDataExfil"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.soar_dispatcher[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.data_exfil[0].arn
}

resource "aws_lambda_permission" "s3_public" {
  count         = local.enable_infra ? 1 : 0
  statement_id  = "AllowS3Public"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.soar_dispatcher[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_public[0].arn
}

resource "aws_lambda_permission" "network_threat" {
  count         = local.enable_network ? 1 : 0
  statement_id  = "AllowNetworkThreat"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.soar_dispatcher[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.network_threat[0].arn
}

resource "aws_lambda_permission" "config_iam_change" {
  count         = local.enable_iam ? 1 : 0
  statement_id  = "AllowConfigIAM"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.soar_dispatcher[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.config_iam_change[0].arn
}