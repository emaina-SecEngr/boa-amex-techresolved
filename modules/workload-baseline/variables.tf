# ============================================================
# AWS SECURITY SERVICES — COMPLETE TOOLKIT
# Each service is toggleable per workload account
# Production accounts: most services enabled
# Dev/sandbox accounts: minimal services enabled
# PCI-CDE accounts: ALL services enabled
#
# LBB Scheduler is the workload application deployed
# into these accounts — all tools protect LBB
# ============================================================

# -----------------------------------------------------------
# CORE MODULE INPUTS — account identity, networking, baseline
# hardening. Referenced directly by main.tf.
# -----------------------------------------------------------
variable "project_prefix" {
  description = "Short prefix identifying this project, used in resource naming (e.g. \"boa-amex\")."
  type        = string
}

variable "account_name" {
  description = "Name of the workload account this baseline is deployed into (e.g. \"dev\", \"pci-cde\", \"pipeline\")."
  type        = string
}

variable "environment" {
  description = "Deployment environment for this account."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Must be dev, staging, or prod."
  }
}

variable "data_classification" {
  description = "Sensitivity classification of data handled in this account, used for tagging and audit evidence."
  type        = string
  default     = "internal"
}

variable "common_tags" {
  description = "Common tags applied to every resource in this module, merged with module-specific tags."
  type        = map(string)
  default     = {}
}

variable "security_tooling_account_id" {
  description = "AWS account ID of the central Security Tooling account, granted decrypt access on the workload KMS key."
  type        = string
}

variable "security_alert_email" {
  description = "Email address subscribed to this account's security alerts SNS topic."
  type        = string
}

# --- Networking ---
variable "vpc_cidr" {
  description = "CIDR block for the workload VPC."
  type        = string
}

variable "availability_zones" {
  description = "Availability zones to spread subnets across."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public (ALB-only) subnets, one per availability zone."
  type        = list(string)
  default     = []
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private (LBB application tier) subnets, one per availability zone."
  type        = list(string)
}

variable "isolated_subnet_cidrs" {
  description = "CIDR blocks for isolated (LBB database tier) subnets, one per availability zone."
  type        = list(string)
}

variable "enable_public_subnets" {
  description = "Create public subnets and an ALB security group. Disable for accounts with no internet-facing components."
  type        = bool
  default     = true
}

variable "enable_internet_gateway" {
  description = "Attach an Internet Gateway to the VPC for public subnet egress/ingress."
  type        = bool
  default     = true
}

variable "enable_nat_gateway" {
  description = "Create a NAT Gateway for private subnet outbound internet access."
  type        = bool
  default     = true
}

variable "enable_transit_gateway" {
  description = "Attach this VPC to the central Transit Gateway for hub-and-spoke connectivity."
  type        = bool
  default     = false
}

variable "transit_gateway_id" {
  description = "ID of the Transit Gateway to attach when enable_transit_gateway is true."
  type        = string
  default     = ""
}

variable "enable_vpc_endpoints" {
  description = "Create VPC endpoints (S3 gateway + interface endpoints) for private AWS API access."
  type        = bool
  default     = true
}

variable "vpc_endpoint_services" {
  description = "AWS services to create interface VPC endpoints for (include \"s3\" to also get the gateway endpoint)."
  type        = list(string)
  default     = ["s3", "secretsmanager", "kms", "logs", "monitoring", "sts"]
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs for network visibility."
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "Retention period in days for VPC Flow Log CloudWatch Logs."
  type        = number
  default     = 365
}

# --- Baseline hardening ---
variable "enforce_imdsv2" {
  description = "Enforce IMDSv2 account-wide default for new EC2 instances — prevents SSRF-to-credential-theft attacks."
  type        = bool
  default     = true
}

variable "enable_ebs_encryption" {
  description = "Enable EBS encryption by default at the account level."
  type        = bool
  default     = true
}

variable "enable_s3_block_public" {
  description = "Enable S3 Block Public Access at the account level."
  type        = bool
  default     = true
}

variable "create_workload_kms_key" {
  description = "Create a dedicated KMS key for this workload account's data encryption."
  type        = bool
  default     = true
}

variable "kms_key_rotation" {
  description = "Enable automatic annual rotation of the workload KMS key."
  type        = bool
  default     = true
}

# --- Third-party: Wiz ---
variable "wiz_aws_account_id" {
  description = "AWS account ID Wiz assumes the WizScanner role from."
  type        = string
  default     = ""
}

variable "wiz_external_id" {
  description = "External ID required in the WizScanner role trust policy, provided by Wiz."
  type        = string
  default     = ""
  sensitive   = true
}

# -----------------------------------------------------------
# TIER 1: THREAT DETECTION
# -----------------------------------------------------------
variable "enable_guardduty" {
  description = "GuardDuty enrollment — ML-based threat detection analyzing CloudTrail, VPC Flows, DNS. Detects threats against LBB infrastructure."
  type        = bool
  default     = true
}

variable "enable_guardduty_s3_protection" {
  description = "GuardDuty S3 Protection — monitors S3 data events. Detects unusual access to LBB data buckets."
  type        = bool
  default     = true
}

variable "enable_guardduty_eks_protection" {
  description = "GuardDuty EKS Protection — monitors Kubernetes audit logs. Enable when LBB runs on EKS."
  type        = bool
  default     = false
}

variable "enable_guardduty_rds_protection" {
  description = "GuardDuty RDS Protection — monitors database login events. Detects brute force against LBB PostgreSQL."
  type        = bool
  default     = true
}

variable "enable_guardduty_lambda_protection" {
  description = "GuardDuty Lambda Protection — monitors Lambda network activity. Detects C2 from LBB serverless functions."
  type        = bool
  default     = true
}

variable "enable_guardduty_malware_protection" {
  description = "GuardDuty Malware Protection — scans EBS volumes of suspicious LBB instances for malware."
  type        = bool
  default     = true
}

variable "enable_guardduty_runtime_monitoring" {
  description = "GuardDuty Runtime Monitoring — agent-based runtime detection for LBB EC2/ECS workloads."
  type        = bool
  default     = false
}

variable "enable_detective" {
  description = "Amazon Detective — behavior graph for investigating security incidents against LBB. Links GuardDuty findings to forensic timeline."
  type        = bool
  default     = true
}

variable "enable_security_lake" {
  description = "Security Lake enrollment — normalizes this account's logs to OCSF for Sentinel ingestion. All LBB activity in standard format."
  type        = bool
  default     = true
}

# -----------------------------------------------------------
# TIER 2: COMPLIANCE AND CONFIGURATION
# -----------------------------------------------------------
variable "enable_security_hub" {
  description = "Security Hub enrollment — compliance standards and finding aggregation for LBB infrastructure."
  type        = bool
  default     = true
}

variable "enable_security_hub_cis" {
  description = "Security Hub CIS AWS Foundations Benchmark — 135 automated controls checking LBB account config."
  type        = bool
  default     = true
}

variable "enable_security_hub_pci" {
  description = "Security Hub PCI-DSS v3.2.1 — required when LBB processes card data. Enable for PCI-CDE account."
  type        = bool
  default     = true
}

variable "enable_security_hub_fsbp" {
  description = "Security Hub AWS Foundational Security Best Practices — 200+ AWS-specific controls."
  type        = bool
  default     = true
}

variable "enable_security_hub_nist" {
  description = "Security Hub NIST 800-53 Rev 5 — federal security controls. Enable for OCC-regulated accounts."
  type        = bool
  default     = false
}

variable "enable_config" {
  description = "AWS Config — tracks every resource configuration change in LBB account. Required for Security Hub."
  type        = bool
  default     = true
}

variable "enable_config_rules" {
  description = "Enable managed Config rules — baseline compliance checking for LBB resources."
  type        = bool
  default     = true
}

variable "config_conformance_packs" {
  description = "Config conformance packs mapping controls to frameworks for LBB account."
  type        = list(string)
  default     = ["Operational-Best-Practices-for-PCI-DSS"]
}

variable "enable_audit_manager" {
  description = "AWS Audit Manager — automated evidence collection for OCC/PCI/SOX audits of LBB. Generates assessment reports. Cost: $1.25/resource assessment."
  type        = bool
  default     = false
}

variable "audit_manager_frameworks" {
  description = "Audit Manager frameworks to assess LBB against."
  type        = list(string)
  default     = ["PCI-DSS-v3.2.1", "CIS-AWS-Foundations-Benchmark-v1.4.0"]
}

# -----------------------------------------------------------
# TIER 3: IDENTITY AND ACCESS
# -----------------------------------------------------------
variable "enable_iam_access_analyzer" {
  description = "IAM Access Analyzer — finds LBB resources shared externally and unused permissions. Detects overly permissive LBB IAM roles."
  type        = bool
  default     = true
}

variable "enable_iam_access_analyzer_unused" {
  description = "IAM Access Analyzer unused access — finds LBB role permissions not used in 90 days. Cost: $0.20/role/month."
  type        = bool
  default     = false
}

variable "enable_permission_boundaries" {
  description = "Deploy IAM Permission Boundaries — prevents LBB developers from creating overprivileged roles even with AdministratorAccess."
  type        = bool
  default     = true
}

variable "permission_boundary_policy_arn" {
  description = "ARN of Permission Boundary policy. If empty a default boundary is created restricting IAM/Org/SCP actions."
  type        = string
  default     = ""
}

variable "enable_identity_center_app" {
  description = "Register LBB Scheduler as IAM Identity Center application — SSO access from AWS portal."
  type        = bool
  default     = false
}

variable "identity_center_app_url" {
  description = "LBB Scheduler URL for Identity Center app registration."
  type        = string
  default     = ""
}

# -----------------------------------------------------------
# TIER 4: DATA PROTECTION
# -----------------------------------------------------------
variable "enable_macie" {
  description = "Amazon Macie — ML-powered data classification for S3. Scans LBB data buckets for PII, PAN, SSN. Critical for PCI-DSS data discovery. Cost: $1/GB scanned."
  type        = bool
  default     = false
}

variable "macie_scan_frequency" {
  description = "How often Macie scans LBB S3 buckets."
  type        = string
  default     = "ONE_TIME"
}

variable "enable_cloudhsm" {
  description = "AWS CloudHSM — FIPS 140-2 Level 3 HSM for LBB payment processing. Required for PCI PIN blocks. Cost: $1,044/month per HSM (min 2 for HA = $2,088/month)."
  type        = bool
  default     = false
}

variable "cloudhsm_cluster_size" {
  description = "Number of CloudHSM instances for LBB. Minimum 2 for HA."
  type        = number
  default     = 2
}

variable "enable_acm_private_ca" {
  description = "ACM Private CA — issues certificates for mTLS between LBB microservices. FastAPI backend to frontend mTLS. Cost: $400/month per CA."
  type        = bool
  default     = false
}

variable "enable_secrets_manager" {
  description = "AWS Secrets Manager — stores and auto-rotates LBB database passwords, API keys, JWT signing keys."
  type        = bool
  default     = true
}

variable "secrets_rotation_days" {
  description = "Days between LBB secret rotation. Banks use 24 hours for critical. PCI-DSS max 90 days."
  type        = number
  default     = 90
}

variable "enable_nitro_enclaves" {
  description = "AWS Nitro Enclaves — isolated compute for LBB tokenization service. Even root cannot access enclave memory. Required for PCI PIN processing."
  type        = bool
  default     = false
}

variable "enable_dlp" {
  description = "Enable DLP controls — S3 bucket tagging for data classification, integration with Macie for sensitive data detection in LBB data stores."
  type        = bool
  default     = false
}

# -----------------------------------------------------------
# TIER 5: NETWORK SECURITY
# -----------------------------------------------------------
variable "enable_waf" {
  description = "AWS WAF — web application firewall for LBB ALB/API Gateway. Blocks SQL injection, XSS, bot attacks against LBB endpoints."
  type        = bool
  default     = false
}

variable "waf_managed_rules" {
  description = "WAF managed rule groups protecting LBB."
  type        = list(string)
  default = [
    "AWSManagedRulesCommonRuleSet",
    "AWSManagedRulesSQLiRuleSet",
    "AWSManagedRulesKnownBadInputsRuleSet"
  ]
}

variable "enable_shield_advanced" {
  description = "AWS Shield Advanced — DDoS protection for LBB with DDoS Response Team. Cost: $3,000/month. Enable for customer-facing LBB production."
  type        = bool
  default     = false
}

variable "enable_firewall_manager" {
  description = "AWS Firewall Manager — centrally manage WAF and SG rules for LBB from Security Tooling. Cost: $100/month per policy."
  type        = bool
  default     = false
}

variable "enable_network_access_analyzer" {
  description = "AWS Network Access Analyzer — finds unintended network paths to LBB databases. Answers: can the internet reach LBB RDS?"
  type        = bool
  default     = false
}

variable "enable_verified_access" {
  description = "AWS Verified Access — Zero Trust access to LBB without VPN. Verifies identity + device posture. Cost: $0.27/hour."
  type        = bool
  default     = false
}

# -----------------------------------------------------------
# TIER 6: VULNERABILITY MANAGEMENT
# -----------------------------------------------------------
variable "enable_inspector" {
  description = "Amazon Inspector — continuously scans LBB EC2, containers, Lambda for CVEs. Finds vulnerabilities before attackers do."
  type        = bool
  default     = true
}

variable "enable_inspector_ec2" {
  description = "Inspector EC2 scanning — OS and package CVEs on LBB servers."
  type        = bool
  default     = true
}

variable "enable_inspector_ecr" {
  description = "Inspector ECR scanning — container image CVEs in LBB Docker images before deployment."
  type        = bool
  default     = true
}

variable "enable_inspector_lambda" {
  description = "Inspector Lambda scanning — dependency CVEs in LBB serverless functions."
  type        = bool
  default     = true
}

variable "enable_inspector_network" {
  description = "Inspector network reachability — finds LBB resources reachable from internet that should not be."
  type        = bool
  default     = true
}

variable "enable_patch_manager" {
  description = "AWS SSM Patch Manager — automated patching for LBB EC2 instances. Scheduled maintenance windows."
  type        = bool
  default     = true
}

variable "patch_window_schedule" {
  description = "LBB patching window. Cron expression. Default: Sunday 2 AM."
  type        = string
  default     = "cron(0 2 ? * SUN *)"
}

variable "patch_approval_days" {
  description = "Days after patch release before auto-approval for LBB. PCI-DSS: critical within 30 days."
  type        = number
  default     = 7
}

# -----------------------------------------------------------
# TIER 7: APPLICATION SECURITY
# -----------------------------------------------------------
variable "enable_cognito" {
  description = "AWS Cognito — user authentication for LBB customer-facing features. Sign-up, sign-in, MFA, social login. Cost: $0.0055/MAU after 50K free."
  type        = bool
  default     = false
}

variable "cognito_mfa_configuration" {
  description = "Cognito MFA for LBB users."
  type        = string
  default     = "OPTIONAL"
}

variable "enable_api_gateway" {
  description = "AWS API Gateway — managed API endpoint for LBB FastAPI backend. Authentication, throttling, request validation."
  type        = bool
  default     = false
}

variable "api_gateway_auth_type" {
  description = "LBB API Gateway authorization type."
  type        = string
  default     = "COGNITO"

  validation {
    condition     = contains(["COGNITO", "IAM", "LAMBDA", "JWT"], var.api_gateway_auth_type)
    error_message = "Must be COGNITO, IAM, LAMBDA, or JWT."
  }
}

# -----------------------------------------------------------
# TIER 8: CONTAINER AND SERVERLESS SECURITY
# -----------------------------------------------------------
variable "enable_ecr" {
  description = "Amazon ECR — private Docker registry for LBB container images. Scanning, signing, replication."
  type        = bool
  default     = false
}

variable "enable_ecr_scanning" {
  description = "ECR scan on push — scan LBB images for CVEs before deployment."
  type        = bool
  default     = true
}

variable "enable_ecr_immutable_tags" {
  description = "ECR immutable tags — LBB production:v1.2.3 cannot be overwritten."
  type        = bool
  default     = true
}

variable "enable_eks" {
  description = "Amazon EKS — Kubernetes for LBB if container orchestration needed. Includes IRSA, pod security, audit logging."
  type        = bool
  default     = false
}

variable "enable_eks_audit_logging" {
  description = "EKS audit logging to CloudTrail — required for GuardDuty EKS protection of LBB pods."
  type        = bool
  default     = true
}

variable "enable_eks_secrets_encryption" {
  description = "EKS secrets encryption with KMS — encrypt LBB Kubernetes secrets at rest."
  type        = bool
  default     = true
}

# -----------------------------------------------------------
# TIER 9: AUDIT AND FORENSICS
# -----------------------------------------------------------
variable "enable_cloudtrail" {
  description = "Account-level CloudTrail — supplements org trail with LBB-specific data events."
  type        = bool
  default     = true
}

variable "enable_cloudtrail_data_events" {
  description = "CloudTrail data events — shows who accessed which LBB S3 objects and invoked which Lambda. Cost: $0.10/100K events."
  type        = bool
  default     = false
}

variable "enable_cloudtrail_lake" {
  description = "CloudTrail Lake — SQL queries on LBB CloudTrail events. 7-year searchable history. Cost: $2.50/GB scanned."
  type        = bool
  default     = false
}

# -----------------------------------------------------------
# TIER 10: THIRD-PARTY SECURITY TOOLS
# -----------------------------------------------------------
variable "enable_wiz_scanning" {
  description = "Create WizScanner role — CNAPP agentless scanning of LBB infrastructure (CSPM, CWPP, CIEM, data scanning)."
  type        = bool
  default     = true
}

variable "enable_crowdstrike_sensor" {
  description = "Deploy CrowdStrike Falcon sensor — EDR/XDR endpoint protection on LBB servers. Detects mimikatz, reverse shells, fileless malware."
  type        = bool
  default     = false
}

variable "enable_crowdstrike_horizon" {
  description = "Create CrowdStrike Falcon Horizon CSPM role — cloud configuration scanning of LBB account."
  type        = bool
  default     = false
}

variable "enable_sentinel_connector" {
  description = "Configure LBB account logs to flow to Microsoft Sentinel via Security Lake for unified SIEM correlation."
  type        = bool
  default     = false
}

# -----------------------------------------------------------
# TIER 11: GOVERNANCE AND COST
# -----------------------------------------------------------
variable "enable_service_catalog" {
  description = "AWS Service Catalog — approved infrastructure products. LBB developers choose from approved RDS, ECS, Lambda templates only."
  type        = bool
  default     = false
}

variable "enable_budgets" {
  description = "AWS Budgets — cost monitoring for LBB account. Alert when 80% of budget reached."
  type        = bool
  default     = true
}

variable "monthly_budget_amount" {
  description = "Monthly budget threshold for LBB account in USD."
  type        = number
  default     = 100
}

variable "budget_alert_email" {
  description = "Email for LBB budget alerts."
  type        = string
  default     = "emaina@arizona.edu"
}

# -----------------------------------------------------------
# TIER 12: LBB SCHEDULER APPLICATION
# -----------------------------------------------------------
variable "enable_lbb_scheduler" {
  description = "Deploy LBB Scheduler application stack — FastAPI backend, React frontend, PostgreSQL database."
  type        = bool
  default     = false
}

variable "lbb_backend_type" {
  description = "LBB backend compute type."
  type        = string
  default     = "ecs-fargate"

  validation {
    condition     = contains(["ecs-fargate", "ecs-ec2", "ec2", "lambda"], var.lbb_backend_type)
    error_message = "Must be ecs-fargate, ecs-ec2, ec2, or lambda."
  }
}

variable "lbb_db_engine" {
  description = "LBB database engine."
  type        = string
  default     = "postgres"
}

variable "lbb_db_instance_class" {
  description = "RDS instance class for LBB PostgreSQL."
  type        = string
  default     = "db.t3.micro"
}

variable "lbb_frontend_type" {
  description = "LBB frontend hosting type."
  type        = string
  default     = "s3-cloudfront"

  validation {
    condition     = contains(["s3-cloudfront", "ecs", "ec2"], var.lbb_frontend_type)
    error_message = "Must be s3-cloudfront, ecs, or ec2."
  }
}

# -----------------------------------------------------------
# SECURITY PRESET — convenience toggle
# Sets multiple security services at once based on
# workload classification
# -----------------------------------------------------------
variable "security_preset" {
  description = "Security preset determining default tool enablement. minimal=sandbox, standard=dev, enhanced=production, pci-cde=card processing, maximum=all tools."
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["minimal", "standard", "enhanced", "pci-cde", "maximum"], var.security_preset)
    error_message = "Must be minimal, standard, enhanced, pci-cde, or maximum."
  }
}

# Preset definitions (referenced in locals in main.tf):
#
# minimal (sandbox — LBB development testing):
#   GuardDuty + Config + CloudTrail only
#   Cost: ~$5/month
#
# standard (dev — LBB development environment):
#   + Security Hub + Inspector + Secrets Manager + VPC Flow Logs
#   Cost: ~$15/month
#
# enhanced (production — LBB production deployment):
#   + Wiz + CrowdStrike + WAF + Macie + Shield
#   Cost: ~$100-200/month + tool licenses
#
# pci-cde (card processing — LBB processing payments):
#   + CloudHSM + Nitro Enclaves + all tools + no internet
#   Cost: ~$2,500-5,000/month + tool licenses
#
# maximum (everything enabled):
#   ALL tools active, ALL protections, ALL monitoring
#   Cost: ~$5,000-10,000/month + tool licenses