# ============================================================
# main.tf - Network perimeter: hub-and-spoke connectivity
# Module: network-perimeter
#
# DEPLOYMENT ACCOUNT: Security Tooling (368351959735)
# PREREQUISITE: modules/palo-alto with enable_transit_gateway = true
#
# Everything here is gated on local.tgw_ready. Until the TGW
# exists (modules/palo-alto enable_transit_gateway = true),
# this module creates nothing.
# ============================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  tgw_ready = var.enable_network_perimeter && var.transit_gateway_id != "" && var.transit_gateway_arn != ""
}

# -----------------------------------------------------------
# RAM SHARE - Transit Gateway
# Lets workload accounts (PCI-CDE, Core Banking, Dev,
# Pipeline/CI-CD) attach their VPCs to the Security Tooling
# TGW without it living in their own account.
# -----------------------------------------------------------
resource "aws_ram_resource_share" "tgw" {
  count                     = local.tgw_ready ? 1 : 0
  name                      = "${var.project_prefix}-tgw-share"
  allow_external_principals = false

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-tgw-share"
    Purpose = "Shares the Security Tooling Transit Gateway with workload accounts for hub-and-spoke connectivity"
  })
}

resource "aws_ram_resource_association" "tgw" {
  count              = local.tgw_ready ? 1 : 0
  resource_arn       = var.transit_gateway_arn
  resource_share_arn = aws_ram_resource_share.tgw[0].arn
}

# Org-wide share. Requires the one-time
# "aws ram enable-sharing-with-aws-organization" account setting -
# that's an account-level API call, not a Terraform resource, and
# must be run once from the management account before this works.
resource "aws_ram_principal_association" "organization" {
  count              = local.tgw_ready && var.share_tgw_with_organization ? 1 : 0
  principal          = "arn:aws:organizations::${var.management_account_id}:organization/${var.organization_id}"
  resource_share_arn = aws_ram_resource_share.tgw[0].arn
}

resource "aws_ram_principal_association" "additional" {
  for_each           = local.tgw_ready && !var.share_tgw_with_organization ? toset(var.additional_ram_principals) : toset([])
  principal          = each.value
  resource_share_arn = aws_ram_resource_share.tgw[0].arn
}

# -----------------------------------------------------------
# TRANSIT GATEWAY FLOW LOGS
# Captures metadata for all hub-and-spoke traffic
# -----------------------------------------------------------
resource "aws_cloudwatch_log_group" "tgw_flow_log" {
  count             = local.tgw_ready && var.enable_flow_logs ? 1 : 0
  name              = "/aws/transitgateway/flowlogs/${var.project_prefix}"
  retention_in_days = 90

  tags = merge(var.common_tags, {
    Name = "${var.project_prefix}-tgw-flow-logs"
  })
}

resource "aws_iam_role" "tgw_flow_log" {
  count = local.tgw_ready && var.enable_flow_logs ? 1 : 0
  name  = "${var.project_prefix}-tgw-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_prefix}-tgw-flow-log-role"
  })
}

resource "aws_iam_role_policy" "tgw_flow_log" {
  count = local.tgw_ready && var.enable_flow_logs ? 1 : 0
  name  = "${var.project_prefix}-tgw-flow-log-policy"
  role  = aws_iam_role.tgw_flow_log[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "*"
    }]
  })
}

# NOTE: traffic_type is intentionally omitted - it's only valid for
# vpc_id/subnet_id/eni_id flow logs, not transit_gateway_id targets.
resource "aws_flow_log" "tgw" {
  count                = local.tgw_ready && var.enable_flow_logs ? 1 : 0
  transit_gateway_id   = var.transit_gateway_id
  log_destination_type = "cloud-watch-logs"
  iam_role_arn         = aws_iam_role.tgw_flow_log[0].arn
  log_destination      = aws_cloudwatch_log_group.tgw_flow_log[0].arn

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-tgw-flow-logs"
    Purpose = "Hub-and-spoke traffic metadata for threat investigation"
  })
}

# -----------------------------------------------------------
# ALERTING - network segmentation changes
# Fires when a workload VPC is attached, detached, or its
# Transit Gateway attachment is otherwise modified.
# PCI-DSS Req 1 requires change control over network segmentation.
# -----------------------------------------------------------
resource "aws_sns_topic" "network_changes" {
  count = local.tgw_ready && var.enable_change_alerting && var.security_alert_topic_arn == "" ? 1 : 0
  name  = "${var.project_prefix}-network-perimeter-changes"

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-network-perimeter-changes"
    Purpose = "Alerts on Transit Gateway attachment and route table changes"
  })
}

resource "aws_sns_topic_subscription" "network_changes_email" {
  count     = local.tgw_ready && var.enable_change_alerting && var.security_alert_topic_arn == "" ? 1 : 0
  topic_arn = aws_sns_topic.network_changes[0].arn
  protocol  = "email"
  endpoint  = var.security_alert_email
}

locals {
  alert_topic_arn = var.security_alert_topic_arn != "" ? var.security_alert_topic_arn : (
    local.tgw_ready && var.enable_change_alerting && length(aws_sns_topic.network_changes) > 0 ? aws_sns_topic.network_changes[0].arn : ""
  )
}

resource "aws_cloudwatch_event_rule" "tgw_changes" {
  count       = local.tgw_ready && var.enable_change_alerting ? 1 : 0
  name        = "${var.project_prefix}-tgw-attachment-changes"
  description = "Captures Transit Gateway VPC attachment create/delete/accept/reject/modify events for network segmentation change control"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["ec2.amazonaws.com"]
      eventName = [
        "CreateTransitGatewayVpcAttachment",
        "DeleteTransitGatewayVpcAttachment",
        "AcceptTransitGatewayVpcAttachment",
        "RejectTransitGatewayVpcAttachment",
        "ModifyTransitGatewayVpcAttachment"
      ]
    }
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_prefix}-tgw-attachment-changes"
  })
}

resource "aws_cloudwatch_event_target" "tgw_changes_sns" {
  count     = local.tgw_ready && var.enable_change_alerting && local.alert_topic_arn != "" ? 1 : 0
  rule      = aws_cloudwatch_event_rule.tgw_changes[0].name
  target_id = "NetworkPerimeterSNS"
  arn       = local.alert_topic_arn
}

# -----------------------------------------------------------
# WORKLOAD VPC ATTACHMENTS (SPOKES)
# Empty until Phase 5 workload accounts exist. Populate
# var.workload_vpc_attachments once PCI-CDE / Core Banking /
# Dev / Pipeline-CI-CD VPCs are provisioned.
# -----------------------------------------------------------
resource "aws_ec2_transit_gateway_vpc_attachment" "workload" {
  for_each = local.tgw_ready ? var.workload_vpc_attachments : {}

  transit_gateway_id = var.transit_gateway_id
  vpc_id             = each.value.vpc_id
  subnet_ids         = each.value.tgw_subnet_ids

  transit_gateway_default_route_table_association = true
  transit_gateway_default_route_table_propagation = true

  tags = merge(var.common_tags, {
    Name = "${var.project_prefix}-${each.key}-tgw-attachment"
  })
}

resource "aws_route" "workload_default_to_tgw" {
  for_each = local.tgw_ready ? {
    for pair in flatten([
      for name, spoke in var.workload_vpc_attachments : [
        for rt_id in spoke.route_table_ids : {
          key         = "${name}-${rt_id}"
          route_table = rt_id
          workload    = name
        }
      ]
    ]) : pair.key => pair
  } : {}

  route_table_id         = each.value.route_table
  destination_cidr_block = var.default_route_cidr
  transit_gateway_id     = var.transit_gateway_id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.workload]
}

resource "aws_vpc_endpoint" "gwlb_inspection" {
  for_each = local.tgw_ready ? {
    for name, spoke in var.workload_vpc_attachments : name => spoke
    if spoke.enable_gwlb_inspection && var.gwlb_endpoint_service_name != ""
  } : {}

  vpc_id            = each.value.vpc_id
  service_name      = var.gwlb_endpoint_service_name
  vpc_endpoint_type = "GatewayLoadBalancer"
  subnet_ids        = each.value.inspection_subnet_ids

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-${each.key}-gwlb-endpoint"
    Purpose = "Routes ${each.key} workload traffic through centralized Palo Alto inspection"
  })
}

resource "aws_route" "workload_inspection_to_gwlb" {
  for_each = local.tgw_ready ? {
    for pair in flatten([
      for name, spoke in var.workload_vpc_attachments : spoke.enable_gwlb_inspection ? [
        for rt_id in spoke.inspection_route_table_ids : {
          key         = "${name}-${rt_id}-inspect"
          route_table = rt_id
          workload    = name
        }
      ] : []
    ]) : pair.key => pair
  } : {}

  route_table_id         = each.value.route_table
  destination_cidr_block = var.default_route_cidr
  vpc_endpoint_id        = aws_vpc_endpoint.gwlb_inspection[each.value.workload].id
}
