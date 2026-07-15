# ============================================================
# main.tf — Palo Alto VM-Series NGFW + AWS Network Firewall
# Module: palo-alto
#
# DEPLOYMENT ACCOUNT: Security Tooling (368351959735)
# ALL RESOURCES TOGGLED OFF BY DEFAULT
# enable_palo_alto = false
# enable_aws_network_firewall = false
# enable_transit_gateway = false
# ============================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

# -----------------------------------------------------------
# SECURITY VPC
# Hosts firewall inspection infrastructure
# All workload VPC traffic routes through here
# Created regardless of firewall toggle —
# needed as foundation for both Palo Alto and AWS NFW
# -----------------------------------------------------------
resource "aws_vpc" "security" {
  count      = var.enable_palo_alto || var.enable_aws_network_firewall ? 1 : 0
  cidr_block = var.security_vpc_cidr

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-security-vpc"
    Purpose = "Security inspection VPC - all workload traffic inspected here"
  })
}

# Inspection subnets — one per AZ
# Firewall endpoints deployed here
resource "aws_subnet" "inspection" {
  count             = var.enable_palo_alto || var.enable_aws_network_firewall ? length(var.availability_zones) : 0
  vpc_id            = aws_vpc.security[0].id
  cidr_block        = var.inspection_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-inspection-subnet-${var.availability_zones[count.index]}"
    Purpose = "Firewall inspection subnet"
    Tier    = "inspection"
  })
}

# Management subnets — Palo Alto management access
resource "aws_subnet" "management" {
  count             = var.enable_palo_alto ? length(var.availability_zones) : 0
  vpc_id            = aws_vpc.security[0].id
  cidr_block        = var.management_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-mgmt-subnet-${var.availability_zones[count.index]}"
    Purpose = "Firewall management subnet"
    Tier    = "management"
  })
}

# Internet Gateway for Security VPC
resource "aws_internet_gateway" "security" {
  count  = var.enable_palo_alto || var.enable_aws_network_firewall ? 1 : 0
  vpc_id = aws_vpc.security[0].id

  tags = merge(var.common_tags, {
    Name = "${var.project_prefix}-security-igw"
  })
}

# -----------------------------------------------------------
# VPC FLOW LOGS — Security VPC
# Captures all traffic metadata for Security Lake → Sentinel
# -----------------------------------------------------------
resource "aws_flow_log" "security_vpc" {
  count           = var.enable_palo_alto || var.enable_aws_network_firewall ? 1 : 0
  vpc_id          = aws_vpc.security[0].id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_log[0].arn
  log_destination = aws_cloudwatch_log_group.flow_log[0].arn

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-security-vpc-flow-logs"
    Purpose = "Security VPC traffic metadata for threat investigation"
  })
}

resource "aws_cloudwatch_log_group" "flow_log" {
  count             = var.enable_palo_alto || var.enable_aws_network_firewall ? 1 : 0
  name              = "/aws/vpc/flowlogs/${var.project_prefix}-security"
  retention_in_days = 90

  tags = merge(var.common_tags, {
    Name = "${var.project_prefix}-security-vpc-flow-logs"
  })
}

resource "aws_iam_role" "flow_log" {
  count = var.enable_palo_alto || var.enable_aws_network_firewall ? 1 : 0
  name  = "${var.project_prefix}-vpc-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_prefix}-vpc-flow-log-role"
  })
}

resource "aws_iam_role_policy" "flow_log" {
  count = var.enable_palo_alto || var.enable_aws_network_firewall ? 1 : 0
  name  = "${var.project_prefix}-vpc-flow-log-policy"
  role  = aws_iam_role.flow_log[0].id

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

# -----------------------------------------------------------
# TRANSIT GATEWAY
# Hub connecting all VPCs — routes traffic through Security VPC
# -----------------------------------------------------------
resource "aws_ec2_transit_gateway" "main" {
  count       = var.enable_transit_gateway ? 1 : 0
  description = "${var.project_prefix} Transit Gateway — hub-and-spoke VPC connectivity"

  amazon_side_asn                 = var.transit_gateway_asn
  auto_accept_shared_attachments  = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-transit-gateway"
    Purpose = "Hub connecting all VPCs - traffic routed through Security VPC for inspection"
  })
}

# TGW attachment for Security VPC
resource "aws_ec2_transit_gateway_vpc_attachment" "security" {
  count              = var.enable_transit_gateway && (var.enable_palo_alto || var.enable_aws_network_firewall) ? 1 : 0
  subnet_ids         = aws_subnet.inspection[*].id
  transit_gateway_id = aws_ec2_transit_gateway.main[0].id
  vpc_id             = aws_vpc.security[0].id

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-security-vpc-tgw-attachment"
    Purpose = "Security VPC attachment to Transit Gateway"
  })
}

# -----------------------------------------------------------
# AWS NETWORK FIREWALL
# Alternative to Palo Alto — cheaper, AWS managed
# Suricata-based IDS/IPS with domain filtering
# -----------------------------------------------------------
resource "aws_networkfirewall_firewall" "main" {
  count               = var.enable_aws_network_firewall ? 1 : 0
  name                = "${var.project_prefix}-network-firewall"
  vpc_id              = aws_vpc.security[0].id
  firewall_policy_arn = aws_networkfirewall_firewall_policy.main[0].arn

  delete_protection                 = var.network_firewall_delete_protection
  firewall_policy_change_protection = false
  subnet_change_protection          = false

  dynamic "subnet_mapping" {
    for_each = aws_subnet.inspection
    content {
      subnet_id = subnet_mapping.value.id
    }
  }

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-network-firewall"
    Purpose = "AWS Network Firewall - Suricata IDS/IPS baseline inspection"
  })
}

# Firewall policy
resource "aws_networkfirewall_firewall_policy" "main" {
  count = var.enable_aws_network_firewall ? 1 : 0
  name  = "${var.project_prefix}-firewall-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.domain_block[0].arn
    }

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.suricata_rules[0].arn
    }

    stateful_engine_options {
      rule_order = "STRICT_ORDER"
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_prefix}-firewall-policy"
  })
}

# Domain block rule group
resource "aws_networkfirewall_rule_group" "domain_block" {
  count    = var.enable_aws_network_firewall ? 1 : 0
  capacity = 100
  name     = "${var.project_prefix}-domain-block"
  type     = "STATEFUL"

  rule_group {
    rules_source {
      rules_source_list {
        generated_rules_type = "DENYLIST"
        target_types         = ["HTTP_HOST", "TLS_SNI"]
        targets              = var.blocked_domains
      }
    }
    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }
  }

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-domain-block"
    Purpose = "Block known malicious and unauthorized domains"
  })
}

# Suricata IDS/IPS rules
resource "aws_networkfirewall_rule_group" "suricata_rules" {
  count    = var.enable_aws_network_firewall && var.enable_suricata_rules ? 1 : 0
  capacity = 1000
  name     = "${var.project_prefix}-suricata-rules"
  type     = "STATEFUL"

  rule_group {
    rules_source {
      rules_string = <<-EOT
        # Block Tor exit nodes
        drop tcp any any -> any any (msg:"Tor exit node detected"; flow:established; content:"tor"; nocase; sid:1000001; rev:1;)
        
        # Detect port scanning
        alert tcp any any -> $HOME_NET any (msg:"Possible port scan"; flags:S; threshold:type both, track by_src, count 20, seconds 60; sid:1000002; rev:1;)
        
        # Detect DNS tunneling
        alert dns any any -> any any (msg:"Possible DNS tunneling - long query"; dns.query; content:"."; byte_test:1,>,50,0,relative; sid:1000003; rev:1;)
        
        # Block C2 communication patterns
        drop tcp any any -> any any (msg:"Possible C2 beacon - periodic connection"; flow:established; detection_filter:track by_src, count 100, seconds 60; sid:1000004; rev:1;)
        
        # Detect credential dumping tools
        alert http any any -> any any (msg:"Possible credential dumping tool download"; http.uri; content:"mimikatz"; nocase; sid:1000005; rev:1;)
        
        # Block known malware ports
        drop tcp any any -> any [4444,8080,1234,6666] (msg:"Possible malware C2 port"; flow:to_server; sid:1000006; rev:1;)
      EOT
    }
    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }
  }

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-suricata-rules"
    Purpose = "Suricata IDS/IPS rules for threat detection"
  })
}

# Firewall logging
resource "aws_networkfirewall_logging_configuration" "main" {
  count        = var.enable_aws_network_firewall && var.enable_firewall_logs ? 1 : 0
  firewall_arn = aws_networkfirewall_firewall.main[0].arn

  logging_configuration {
    log_destination_config {
      log_destination = {
        logGroup = "/aws/networkfirewall/${var.project_prefix}/alerts"
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "ALERT"
    }

    log_destination_config {
      log_destination = {
        bucketName = var.log_archive_bucket_name
        prefix     = "network-firewall/flows"
      }
      log_destination_type = "S3"
      log_type             = "FLOW"
    }
  }
}

# CloudWatch log group for firewall alerts
resource "aws_cloudwatch_log_group" "firewall_alerts" {
  count             = var.enable_aws_network_firewall ? 1 : 0
  name              = "/aws/networkfirewall/${var.project_prefix}/alerts"
  retention_in_days = 90

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-firewall-alerts"
    Purpose = "Network Firewall alert logs for threat investigation"
  })
}

# -----------------------------------------------------------
# PALO ALTO VM-SERIES
# Full NGFW with App-ID, SSL decryption, WildFire
# -----------------------------------------------------------

# Security Group for Palo Alto management
resource "aws_security_group" "palo_alto_mgmt" {
  count       = var.enable_palo_alto ? 1 : 0
  name        = "${var.project_prefix}-palo-alto-mgmt"
  description = "Security group for Palo Alto management access"
  vpc_id      = aws_vpc.security[0].id

  ingress {
    description = "HTTPS management from Security Tooling"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.security_vpc_cidr]
  }

  ingress {
    description = "SSH management from Security Tooling"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.security_vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-palo-alto-mgmt-sg"
    Purpose = "Palo Alto VM-Series management access"
  })
}

# Gateway Load Balancer — distributes traffic to Palo Alto
resource "aws_lb" "gwlb" {
  count              = var.enable_palo_alto ? 1 : 0
  name               = "${var.project_prefix}-gwlb"
  load_balancer_type = "gateway"
  subnets            = aws_subnet.inspection[*].id

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-gwlb"
    Purpose = "Gateway Load Balancer - distributes traffic to Palo Alto cluster"
  })
}

resource "aws_lb_target_group" "palo_alto" {
  count       = var.enable_palo_alto ? 1 : 0
  name        = "${var.project_prefix}-pa-tg"
  port        = 6081
  protocol    = "GENEVE"
  vpc_id      = aws_vpc.security[0].id
  target_type = "instance"

  health_check {
    port     = 80
    protocol = "HTTP"
    path     = "/"
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_prefix}-palo-alto-target-group"
  })
}

resource "aws_lb_listener" "gwlb" {
  count             = var.enable_palo_alto ? 1 : 0
  load_balancer_arn = aws_lb.gwlb[0].arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.palo_alto[0].arn
  }
}

# Palo Alto EC2 instances
resource "aws_instance" "palo_alto" {
  count         = var.enable_palo_alto ? var.palo_alto_instance_count : 0
  ami           = var.palo_alto_ami_id
  instance_type = var.palo_alto_instance_type
  subnet_id     = aws_subnet.inspection[count.index % length(aws_subnet.inspection)].id

  vpc_security_group_ids = [aws_security_group.palo_alto_mgmt[0].id]

  user_data = base64encode(<<-EOF
    type=dhcp-client
    hostname=${var.project_prefix}-pa-fw-${count.index + 1}
    ip-address=
    default-gateway=
    netmask=
    panorama-server=${var.panorama_server}
    tplname=${var.panorama_device_group}
    dgname=${var.panorama_device_group}
    vm-auth-key=
  EOF
  )

  root_block_device {
    volume_type = "gp3"
    volume_size = 60
    encrypted   = true
  }

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-palo-alto-fw-${count.index + 1}"
    Purpose = "Palo Alto VM-Series NGFW instance ${count.index + 1}"
  })
}

# Register Palo Alto instances with GWLB target group
resource "aws_lb_target_group_attachment" "palo_alto" {
  count            = var.enable_palo_alto ? var.palo_alto_instance_count : 0
  target_group_arn = aws_lb_target_group.palo_alto[0].arn
  target_id        = aws_instance.palo_alto[count.index].id
}

# VPC Endpoint Service — exposes GWLB to other VPCs
resource "aws_vpc_endpoint_service" "gwlb" {
  count                      = var.enable_palo_alto ? 1 : 0
  acceptance_required        = false
  gateway_load_balancer_arns = [aws_lb.gwlb[0].arn]

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-gwlb-endpoint-service"
    Purpose = "GWLB endpoint service - workload VPCs connect here for inspection"
  })
}

# -----------------------------------------------------------
# SNS ALERT FOR CRITICAL FIREWALL EVENTS
# -----------------------------------------------------------
resource "aws_sns_topic" "firewall_alerts" {
  count = var.enable_palo_alto || var.enable_aws_network_firewall ? 1 : 0
  name  = "${var.project_prefix}-firewall-alerts"

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-firewall-alerts"
    Purpose = "Critical firewall threat detection alerts"
  })
}

resource "aws_sns_topic_subscription" "firewall_email" {
  count     = var.enable_palo_alto || var.enable_aws_network_firewall ? 1 : 0
  topic_arn = aws_sns_topic.firewall_alerts[0].arn
  protocol  = "email"
  endpoint  = var.security_alert_email
}

# EventBridge rule for Network Firewall alerts
resource "aws_cloudwatch_event_rule" "firewall_threat" {
  count       = var.enable_aws_network_firewall ? 1 : 0
  name        = "${var.project_prefix}-firewall-threat"
  description = "Captures Network Firewall ALERT log entries indicating threats"

  event_pattern = jsonencode({
    source      = ["aws.network-firewall"]
    detail-type = ["Network Firewall Alert"]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_prefix}-firewall-threat"
  })
}

resource "aws_cloudwatch_event_target" "firewall_sns" {
  count     = var.enable_aws_network_firewall && length(aws_sns_topic.firewall_alerts) > 0 ? 1 : 0
  rule      = aws_cloudwatch_event_rule.firewall_threat[0].name
  target_id = "FirewallSNS"
  arn       = aws_sns_topic.firewall_alerts[0].arn
}