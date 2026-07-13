# ============================================================
# main.tf — Amazon Detective behavior graph
# Module: detective
#
# DEPLOYMENT ACCOUNT: Security Tooling (368351959735)
# PREREQUISITE: guardduty module complete
# IMPORT REQUIRED:
#   terraform import module.detective.aws_detective_graph.main \
#     arn:aws:detective:us-east-1:368351959735:graph:97cadf0d24b147f0bfd76cfac41ea1a1
# ============================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

# -----------------------------------------------------------
# DETECTIVE GRAPH
# The behavior graph — imported from existing graph
# Correlates CloudTrail + VPC Flow Logs + GuardDuty
# -----------------------------------------------------------
resource "aws_detective_graph" "main" {
  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-detective-graph"
    Purpose = "Behavior graph for security investigation and incident response"
  })
}

# -----------------------------------------------------------
# MEMBER ACCOUNT INVITATION
# Invite member accounts into the behavior graph
# Their CloudTrail and VPC Flow Logs contribute to graph
# -----------------------------------------------------------
resource "aws_detective_member" "audit" {
  count      = contains(var.member_accounts, var.audit_account_id) ? 1 : 0
  account_id = var.audit_account_id
  email_address = lookup(
    var.member_emails,
    var.audit_account_id,
    "mwangi.maina83+audit@gmail.com"
  )
  graph_arn = aws_detective_graph.main.graph_arn
  message   = "You are invited to join the BOA-AMEX security investigation graph. This enables cross-account threat investigation and incident response."

  disable_email_notification = false

  lifecycle {
    ignore_changes = [email_address]
  }
}

# -----------------------------------------------------------
# CLOUDWATCH ALARM — Detective data volume spike
# Spike in data ingestion indicates active investigation
# or unusual activity generating large volumes of logs
# -----------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "detective_volume_spike" {
  alarm_name          = "${var.project_prefix}-detective-volume-spike"
  alarm_description   = "Detective data ingestion spike — possible active attack generating high log volume or ongoing investigation"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "IngestVolume"
  namespace           = "AWS/Detective"
  period              = 3600
  statistic           = "Sum"
  threshold           = 1000
  treat_missing_data  = "notBreaching"

  tags = merge(var.common_tags, {
    Name     = "${var.project_prefix}-detective-volume-spike"
    Severity = "MEDIUM"
  })
}