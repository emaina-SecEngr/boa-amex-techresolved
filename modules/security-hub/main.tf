# ============================================================
# main.tf — Organization-wide Security Hub configuration
# Module: security-hub
#
# DEPLOYMENT ACCOUNT: Security Tooling (368351959735)
# PREREQUISITE: guardduty module complete
# ============================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  # Severity labels to alert on, derived from critical_finding_threshold.
  # CRITICAL alerts on CRITICAL only; each lower threshold adds the next tier.
  severity_tiers = {
    CRITICAL = ["CRITICAL"]
    HIGH     = ["CRITICAL", "HIGH"]
    MEDIUM   = ["CRITICAL", "HIGH", "MEDIUM"]
    LOW      = ["CRITICAL", "HIGH", "MEDIUM", "LOW"]
  }
  alert_severity_labels = local.severity_tiers[var.critical_finding_threshold]
}

# -----------------------------------------------------------
# SECURITY HUB — core enablement
# -----------------------------------------------------------
resource "aws_securityhub_account" "main" {
  enable_default_standards  = false
  auto_enable_controls      = var.auto_enable_controls
  control_finding_generator = var.control_finding_generator

  depends_on = []
}

# -----------------------------------------------------------
# COMPLIANCE STANDARDS
# Each standard runs automated checks continuously
# Findings appear in Security Hub console + EventBridge
# -----------------------------------------------------------

# Standard 1: CIS AWS Foundations Benchmark
resource "aws_securityhub_standards_subscription" "cis" {
  count         = var.enable_cis_standard ? 1 : 0
  standards_arn = "arn:aws:securityhub:${local.region}::standards/cis-aws-foundations-benchmark/v/1.4.0"

  depends_on = [aws_securityhub_account.main]
}

# Standard 2: PCI-DSS v3.2.1
resource "aws_securityhub_standards_subscription" "pci_dss" {
  count         = var.enable_pci_dss_standard ? 1 : 0
  standards_arn = "arn:aws:securityhub:${local.region}::standards/pci-dss/v/3.2.1"

  depends_on = [aws_securityhub_account.main]
}

# Standard 3: AWS Foundational Security Best Practices
resource "aws_securityhub_standards_subscription" "aws_foundational" {
  count         = var.enable_aws_foundational_standard ? 1 : 0
  standards_arn = "arn:aws:securityhub:${local.region}::standards/aws-foundational-security-best-practices/v/1.0.0"

  depends_on = [aws_securityhub_account.main]
}

# Standard 4: NIST SP 800-53 Rev 5 (optional)
resource "aws_securityhub_standards_subscription" "nist" {
  count         = var.enable_nist_standard ? 1 : 0
  standards_arn = "arn:aws:securityhub:${local.region}::standards/nist-800-53/v/5.0.0"

  depends_on = [aws_securityhub_account.main]
}

# -----------------------------------------------------------
# PRODUCT INTEGRATIONS
# Security Hub becomes the single pane of glass by ingesting
# findings from other AWS security services.
#
# FULL AWS-NATIVE INTEGRATION CATALOG (source: AWS Security Hub
# user guide, "AWS service integrations with Security Hub"):
#
# SEND findings into Security Hub:
#   - GuardDuty              (threat detection)               <- explicit subscription below
#   - Inspector              (EC2/ECR/Lambda vuln scanning)    <- explicit subscription below
#   - Macie                  (S3 sensitive-data discovery)     <- explicit subscription below
#   - IAM Access Analyzer    (external/unused access findings) <- explicit subscription below
#   - AWS Config             (Config rule compliance)          -- auto-activates once Config + SecurityHub are both on
#   - AWS Firewall Manager   (WAF/Shield policy compliance)    -- auto-activates
#   - AWS Health             (security/abuse/certificate events) -- auto-activates
#   - AWS IoT Device Defender (IoT audit + detect findings)    -- requires manual "Accept findings" in console/API, no TF resource
#   - Route 53 Resolver DNS Firewall (malicious DNS queries)   -- auto-activates for AWS-managed domain lists
#   - Systems Manager Patch Manager (patch compliance)         -- auto-activates
#
# RECEIVE findings from Security Hub (downstream, not sources):
#   - Amazon Detective        (pivot for investigation)
#   - AWS Audit Manager       (evidence collection)
#   - Amazon Security Lake    (see enable_sentinel_integration -> Sentinel)
#   - Systems Manager Explorer/OpsCenter
#   - AWS Trusted Advisor
#   - Amazon Q Developer in chat apps (Slack/Chime)
#
# NOTE: The "auto-activates" services above have no
# aws_securityhub_product_subscription resource in the AWS
# provider — the integration is wired up automatically as soon
# as both services are enabled in the account, so there is
# nothing to add here in Terraform for them. Attempting to
# force a subscription for an already-auto-enabled product
# fails with ResourceConflictException. GuardDuty/Inspector/
# Macie/Access Analyzer are subscribed explicitly below for
# clarity and because they were the integrations this module
# originally targeted; it is safe to also leave them to
# auto-activate, but explicit subscriptions make the intent
# visible in the plan output.
# -----------------------------------------------------------
resource "aws_securityhub_product_subscription" "guardduty" {
  product_arn = "arn:aws:securityhub:${local.region}::product/aws/guardduty"

  depends_on = [aws_securityhub_account.main]
}

resource "aws_securityhub_product_subscription" "inspector" {
  product_arn = "arn:aws:securityhub:${local.region}::product/aws/inspector"

  depends_on = [aws_securityhub_account.main]
}

resource "aws_securityhub_product_subscription" "macie" {
  product_arn = "arn:aws:securityhub:${local.region}::product/aws/macie"

  depends_on = [aws_securityhub_account.main]
}

resource "aws_securityhub_product_subscription" "iam_access_analyzer" {
  product_arn = "arn:aws:securityhub:${local.region}::product/aws/access-analyzer"

  depends_on = [aws_securityhub_account.main]
}

# -----------------------------------------------------------
# FINDING AGGREGATION
# Pulls findings from all member accounts into
# Security Tooling for unified visibility
# -----------------------------------------------------------
resource "aws_securityhub_finding_aggregator" "main" {
  count        = var.enable_finding_aggregation ? 1 : 0
  linking_mode = "ALL_REGIONS"

  depends_on = [aws_securityhub_account.main]
}

# -----------------------------------------------------------
# ORG-WIDE AUTO-ENABLE
# New accounts automatically get Security Hub enabled
# -----------------------------------------------------------
resource "aws_securityhub_organization_configuration" "main" {
  auto_enable           = var.enable_org_auto_enable
  auto_enable_standards = var.enable_org_auto_enable ? "DEFAULT" : "NONE"

  # LOCAL, not CENTRAL: auto_enable/auto_enable_standards only work in the
  # LOCAL configuration model — AWS rejects them under CENTRAL with
  # "Auto Enable and AutoEnableStandards can not be enabled for Central
  # Configuration". CENTRAL requires a separate configuration-policy +
  # policy-association setup this module doesn't implement.
  organization_configuration {
    configuration_type = "LOCAL"
  }

  depends_on = [
    aws_securityhub_account.main,
    aws_securityhub_finding_aggregator.main
  ]
}

# -----------------------------------------------------------
# CRITICAL FINDING ALERT
# Fires immediately when CRITICAL finding is generated
# Routes to SNS → email/PagerDuty/Teams
# -----------------------------------------------------------
resource "aws_sns_topic" "security_hub_alerts" {
  name = "${var.project_prefix}-security-hub-alerts"

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-security-hub-alerts"
    Purpose = "Critical Security Hub finding alerts"
  })
}

resource "aws_sns_topic_subscription" "security_hub_email" {
  topic_arn = aws_sns_topic.security_hub_alerts.arn
  protocol  = "email"
  endpoint  = var.security_alert_email
}

resource "aws_sns_topic_policy" "security_hub_alerts" {
  arn = aws_sns_topic.security_hub_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgePublish"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.security_hub_alerts.arn
      }
    ]
  })
}

# EventBridge rule — catches findings at or above critical_finding_threshold
resource "aws_cloudwatch_event_rule" "security_hub_critical" {
  name        = "${var.project_prefix}-security-hub-critical"
  description = "Captures Security Hub findings at or above ${var.critical_finding_threshold} severity"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity = {
          Label = local.alert_severity_labels
        }
        Workflow = {
          Status = ["NEW"]
        }
        RecordState = ["ACTIVE"]
      }
    }
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_prefix}-security-hub-critical"
  })
}

resource "aws_cloudwatch_event_target" "security_hub_sns" {
  rule      = aws_cloudwatch_event_rule.security_hub_critical.name
  target_id = "SecurityHubSNS"
  arn       = aws_sns_topic.security_hub_alerts.arn

  input_transformer {
    input_paths = {
      severity    = "$.detail.findings[0].Severity.Label"
      title       = "$.detail.findings[0].Title"
      account     = "$.detail.findings[0].AwsAccountId"
      region      = "$.region"
      description = "$.detail.findings[0].Description"
      remediation = "$.detail.findings[0].Remediation.Recommendation.Text"
      time        = "$.time"
    }
    input_template = <<-EOT
      "SECURITY HUB ALERT"
      "Severity: <severity>"
      "Title: <title>"
      "Account: <account>"
      "Region: <region>"
      "Time: <time>"
      "Description: <description>"
      "Remediation: <remediation>"
    EOT
  }
}

# -----------------------------------------------------------
# COMPLIANCE SCORE ALARM
# Fires when compliance score drops below threshold
# Indicates new failing controls need attention
# -----------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "compliance_score_drop" {
  alarm_name          = "${var.project_prefix}-security-hub-compliance-drop"
  alarm_description   = "Security Hub compliance score dropped — new failing controls detected. Review Security Hub findings immediately."
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "SecurityScore"
  namespace           = "AWS/SecurityHub"
  period              = 86400
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.security_hub_alerts.arn]

  tags = merge(var.common_tags, {
    Name     = "${var.project_prefix}-security-hub-compliance-drop"
    Severity = "HIGH"
  })
}