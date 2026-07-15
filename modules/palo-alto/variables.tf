# ============================================================
# variables.tf — Module input variables
# Module: palo-alto
#
# WHAT THIS MODULE BUILDS:
# Palo Alto VM-Series NGFW in the Security VPC providing:
#   - App-ID: identifies 3000+ applications by behavior
#   - SSL/TLS decryption: inspects encrypted traffic
#   - User-ID: identity-based policy via Entra ID
#   - Threat Prevention: Unit 42 intelligence (5-min updates)
#   - WildFire: cloud sandbox for unknown files/URLs
#   - DNS Security: ML-based DNS threat detection
#
# ARCHITECTURE:
#   Gateway Load Balancer (GWLB) distributes traffic
#   to Palo Alto VM-Series instances for inspection
#   All VPC traffic routes through GWLB endpoints
#   Palo Alto inspects and either allows or blocks
#
# TOGGLE: enable_palo_alto = false by default
#   Cost when enabled: $1,440-5,760/month
#   Enable only for demos or production deployments
#
# ALTERNATIVE: enable_aws_network_firewall = true
#   Uses AWS Network Firewall instead of Palo Alto
#   Cost: $285/month — good for sandbox demos
#   Same architecture, different inspection engine
#
# PRODUCTION COST:
#   Palo Alto VM-Series license: ~$2-5/hr per instance
#   Two instances for HA: ~$1,440-7,200/month
#   Gateway Load Balancer: $0.008/LCU-hour
#   Enterprise license via AWS Marketplace
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

variable "organization_id" {
  description = "AWS Organization ID."
  type        = string
  default     = "o-tlzn7g9bvb"
}

# -----------------------------------------------------------
# MASTER TOGGLES
# -----------------------------------------------------------
variable "enable_palo_alto" {
  description = "Deploy Palo Alto VM-Series NGFW. Expensive — toggle on for demos only. Requires Palo Alto license from AWS Marketplace."
  type        = bool
  default     = false
}

variable "enable_aws_network_firewall" {
  description = "Deploy AWS Network Firewall as alternative to Palo Alto. Cheaper sandbox option. Can run alongside Palo Alto for defense in depth."
  type        = bool
  default     = false
}

# -----------------------------------------------------------
# SECURITY VPC CONFIGURATION
# The Security VPC hosts the firewall inspection layer
# All traffic from workload VPCs routes through here
# -----------------------------------------------------------
variable "security_vpc_cidr" {
  description = "CIDR block for Security VPC. Must not overlap with workload VPCs."
  type        = string
  default     = "10.0.0.0/16"
}

variable "inspection_subnet_cidrs" {
  description = "CIDR blocks for firewall inspection subnets — one per AZ. Palo Alto or Network Firewall endpoints deployed here."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "management_subnet_cidrs" {
  description = "CIDR blocks for firewall management subnets — one per AZ. Management access to Palo Alto instances."
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "availability_zones" {
  description = "Availability zones for firewall deployment. Minimum 2 for high availability."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# -----------------------------------------------------------
# PALO ALTO VM-SERIES CONFIGURATION
# -----------------------------------------------------------
variable "palo_alto_ami_id" {
  description = "Palo Alto VM-Series AMI ID from AWS Marketplace. Subscribe first at marketplace.aws.amazon.com. Different AMI per region and license type."
  type        = string
  default     = ""
}

variable "palo_alto_instance_type" {
  description = "EC2 instance type for Palo Alto VM-Series. Minimum m5.xlarge for production. c5.2xlarge recommended for high throughput."
  type        = string
  default     = "m5.xlarge"
}

variable "palo_alto_instance_count" {
  description = "Number of Palo Alto instances. Minimum 2 for high availability. GWLB distributes traffic across all instances."
  type        = number
  default     = 2
}

variable "palo_alto_version" {
  description = "PAN-OS version to deploy. Check AWS Marketplace for available versions."
  type        = string
  default     = "11.0"
}

variable "panorama_server" {
  description = "Panorama centralized management server IP or hostname. Leave empty for standalone management."
  type        = string
  default     = ""
}

variable "panorama_device_group" {
  description = "Panorama device group for this deployment."
  type        = string
  default     = "BOA-AMEX-AWS"
}

# -----------------------------------------------------------
# AWS NETWORK FIREWALL CONFIGURATION
# Alternative to Palo Alto for sandbox/dev environments
# -----------------------------------------------------------
variable "network_firewall_delete_protection" {
  description = "Prevent accidental deletion of Network Firewall. Set false only when intentionally destroying."
  type        = bool
  default     = false
}

variable "enable_suricata_rules" {
  description = "Enable Suricata IDS/IPS rules on Network Firewall."
  type        = bool
  default     = true
}

variable "blocked_domains" {
  description = "List of domains to block at network level. Supplemented by Palo Alto threat intel and AWS managed domain lists."
  type        = list(string)
  default = [
    "*.tor2web.com",
    "*.onion.to",
    "pastebin.com",
    "*.duckdns.org",
    "*.no-ip.com"
  ]
}

# -----------------------------------------------------------
# TRANSIT GATEWAY CONFIGURATION
# TGW connects all VPCs and routes traffic through Security VPC
# -----------------------------------------------------------
variable "enable_transit_gateway" {
  description = "Deploy Transit Gateway for hub-and-spoke VPC connectivity. Required for Security VPC architecture. Toggle off to save $36/month."
  type        = bool
  default     = false
}

variable "transit_gateway_asn" {
  description = "BGP ASN for Transit Gateway. Must be unique across your network."
  type        = number
  default     = 64512
}

# -----------------------------------------------------------
# LOGGING
# -----------------------------------------------------------
variable "log_archive_bucket_name" {
  description = "S3 bucket for firewall logs. From log-archive module."
  type        = string
  default     = "boa-amex-log-archive-368351959735"
}

variable "log_archive_kms_key_arn" {
  description = "KMS key for log encryption."
  type        = string
  default     = ""
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs for Security VPC. Captures all traffic metadata."
  type        = bool
  default     = true
}

variable "enable_firewall_logs" {
  description = "Enable firewall alert and flow logs to S3 and CloudWatch."
  type        = bool
  default     = true
}

# -----------------------------------------------------------
# SENTINEL INTEGRATION
# -----------------------------------------------------------
variable "enable_sentinel_integration" {
  description = "Route firewall logs to Sentinel via Security Lake. Set false until Azure subscription active."
  type        = bool
  default     = false
}

variable "security_alert_email" {
  description = "Email for critical firewall alerts."
  type        = string
  default     = "emaina@arizona.edu"
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
    Module     = "palo-alto"
  }
}