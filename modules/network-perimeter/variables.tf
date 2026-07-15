# ============================================================
# variables.tf - Module input variables
# Module: network-perimeter
#
# WHAT THIS MODULE BUILDS:
# The workload side of the hub-and-spoke network architecture
# that modules/palo-alto sets up on the hub (Security VPC +
# Transit Gateway + GWLB) side:
#
# 1. RAM share for the Transit Gateway
#    Lets workload accounts (PCI-CDE, Core Banking, Dev,
#    Pipeline/CI-CD) attach their own VPCs to a TGW that lives
#    in the Security Tooling account.
#
# 2. Transit Gateway Flow Logs
#    Captures all hub-and-spoke traffic metadata for
#    investigation and compliance evidence.
#
# 3. Change alerting
#    SNS + EventBridge alert on TGW attachment create / delete /
#    accept / reject / modify - network segmentation change
#    control for PCI-DSS Req 1.
#
# 4. Workload VPC attachments (spokes)
#    For each workload VPC: TGW attachment, default route to
#    the TGW, and (optionally) a GWLB VPC endpoint + route so
#    that VPC's traffic is inspected by the centralized Palo
#    Alto / AWS Network Firewall cluster.
#
# PREREQUISITE: modules/palo-alto with enable_transit_gateway = true
# Until that's on, every resource here stays dormant (count/for_each = 0).
#
# PHASE 5 NOT STARTED: workload_vpc_attachments defaults to {} -
# PCI-CDE, Core Banking, Dev, and Pipeline/CI-CD accounts are all
# still "TBD" per README. Populate this map once those VPCs exist.
#
# NOTE: RAM sharing with your whole AWS Organization also requires
# a one-time account setting that Terraform cannot manage:
#   aws ram enable-sharing-with-aws-organization
# Run that once from the management account before
# share_tgw_with_organization = true will work.
# ============================================================

variable "aws_region" {
  description = "Primary AWS region."
  type        = string
  default     = "us-east-1"
}

variable "project_prefix" {
  description = "Short prefix for resource naming."
  type        = string
  default     = "boa-amex"
}

variable "security_tooling_account_id" {
  description = "Security Tooling account ID."
  type        = string
  default     = "368351959735"
}

variable "management_account_id" {
  description = "Management account ID. Used to build the AWS Organization ARN for RAM sharing."
  type        = string
  default     = "682391277575"
}

variable "organization_id" {
  description = "AWS Organization ID."
  type        = string
  default     = "o-tlzn7g9bvb"
}

# -----------------------------------------------------------
# MASTER TOGGLE
# -----------------------------------------------------------
variable "enable_network_perimeter" {
  description = "Enable network perimeter resources. Combined with transit_gateway_id/arn being non-empty before anything is created."
  type        = bool
  default     = true
}

# -----------------------------------------------------------
# HUB INPUTS - from modules/palo-alto
# -----------------------------------------------------------
variable "transit_gateway_id" {
  description = "Transit Gateway ID from modules/palo-alto. Empty means the TGW doesn't exist yet (enable_transit_gateway=false) - all resources here stay dormant."
  type        = string
  default     = ""
}

variable "transit_gateway_arn" {
  description = "Transit Gateway ARN from modules/palo-alto. Required to create the RAM share."
  type        = string
  default     = ""
}

variable "gwlb_endpoint_service_name" {
  description = "GWLB VPC Endpoint Service name from modules/palo-alto. Spoke VPCs create a GatewayLoadBalancer VPC endpoint against this service for Palo Alto inspection."
  type        = string
  default     = ""
}

# -----------------------------------------------------------
# RAM SHARING
# -----------------------------------------------------------
variable "share_tgw_with_organization" {
  description = "RAM-share the Transit Gateway with the whole AWS Organization so any current or future workload account can attach without per-account RAM management. Requires 'aws ram enable-sharing-with-aws-organization' to have been run once from the management account."
  type        = bool
  default     = true
}

variable "additional_ram_principals" {
  description = "Extra RAM principals (account IDs or OU ARNs) to share the TGW with directly. Only used when share_tgw_with_organization = false."
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------
# WORKLOAD VPC ATTACHMENTS (SPOKES)
# -----------------------------------------------------------
variable "workload_vpc_attachments" {
  description = <<-EOT
    Spoke VPC definitions to attach to the Transit Gateway. Empty by
    default - Phase 5 workload accounts don't exist yet. Populate one
    entry per workload VPC once that account/VPC is provisioned:
      vpc_id                     - the workload VPC to attach
      vpc_cidr                   - that VPC's CIDR block
      tgw_subnet_ids             - subnets for the TGW ENI, one per AZ
      route_table_ids            - workload route tables that need a default route to the TGW
      enable_gwlb_inspection     - create a GWLB VPC endpoint in this VPC and route through it
      inspection_subnet_ids      - subnets for the GWLB endpoint, one per AZ (required if enable_gwlb_inspection)
      inspection_route_table_ids - route tables that should route through the GWLB endpoint instead of straight to the TGW
  EOT
  type = map(object({
    vpc_id                     = string
    vpc_cidr                   = string
    tgw_subnet_ids             = list(string)
    route_table_ids            = list(string)
    enable_gwlb_inspection     = bool
    inspection_subnet_ids      = list(string)
    inspection_route_table_ids = list(string)
  }))
  default = {}
}

variable "default_route_cidr" {
  description = "Destination CIDR used for the default route to the TGW / GWLB endpoint in spoke route tables."
  type        = string
  default     = "0.0.0.0/0"
}

# -----------------------------------------------------------
# FLOW LOGS
# -----------------------------------------------------------
variable "enable_flow_logs" {
  description = "Enable Transit Gateway Flow Logs. Captures metadata for all hub-and-spoke traffic."
  type        = bool
  default     = true
}

# -----------------------------------------------------------
# CHANGE ALERTING
# -----------------------------------------------------------
variable "enable_change_alerting" {
  description = "Enable SNS + EventBridge alerting on Transit Gateway attachment create/delete/accept/reject/modify events."
  type        = bool
  default     = true
}

variable "security_alert_email" {
  description = "Email for network segmentation change alerts."
  type        = string
  default     = "emaina@arizona.edu"
}

variable "security_alert_topic_arn" {
  description = "Existing SNS topic ARN for alerts. If empty creates new topic."
  type        = string
  default     = ""
}

# -----------------------------------------------------------
# SENTINEL INTEGRATION
# -----------------------------------------------------------
variable "enable_sentinel_integration" {
  description = "Route network perimeter logs to Sentinel via Security Lake. Set false until Azure subscription active."
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default = {
    Project    = "BOA-AMEX-TechResolved"
    Owner      = "Eliud-Maina"
    Consultant = "Abuhari-Consulting-Services"
    ManagedBy  = "Terraform"
    Phase      = "3-ExtendedDetection"
    Module     = "network-perimeter"
  }
}
