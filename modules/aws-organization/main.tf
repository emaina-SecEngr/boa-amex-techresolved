# ============================================================
# main.tf — AWS Organization structure
# Module: aws-organization
#
# WHAT THIS FILE DOES:
# Manages the complete AWS Organization governance structure:
#   1. Enables org-wide AWS service access
#   2. Creates Organizational Units (OU folder structure)
#   3. Places existing accounts into correct OUs
#   4. Creates new member accounts (when toggles enabled)
#   5. Configures delegated administrators for security services
#
# WHAT THIS FILE DOES NOT DO:
#   Does not create SCPs (that is modules/iam-identity-center/)
#   Does not deploy security tools (that is Phase 2)
#   Does not configure workload infrastructure (that is Phase 5)
#
# DEPLOYMENT ORDER:
#   This module deploys into the MANAGEMENT account (682391277575)
#   using the default AWS CLI profile
#   All other modules deploy into member accounts
#
# CRITICAL — ACCOUNT CREATION WARNING:
#   aws_organizations_account resources create PERMANENT accounts
#   AWS account deletion requires manual process + 90 days
#   Never set create_* toggles to true without deliberate intent
# ============================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------
# VALIDATE WE ARE IN THE MANAGEMENT ACCOUNT
# This module MUST run in the Management account
# Running it from any other account will fail or create
# an unintended second Organization
# -----------------------------------------------------------
locals {
  is_management_account = data.aws_caller_identity.current.account_id == var.management_account_id

  # Fail fast if running from wrong account
  # This local will cause an error if account ID doesn't match
  validate_account = local.is_management_account ? true : tobool(
    "ERROR: This module must run from Management account ${var.management_account_id}. Current account is ${data.aws_caller_identity.current.account_id}. Check your AWS CLI profile."
  )
}

# -----------------------------------------------------------
# ENABLE ORG-WIDE SERVICE ACCESS
# Allows AWS services to integrate with Organizations
# Must be enabled before delegated admin can be configured
# Each service principal here enables:
#   - Service-linked roles in all member accounts
#   - Cross-account data sharing for that service
#   - Automatic enrollment for new accounts added later
# -----------------------------------------------------------
resource "aws_organizations_organization" "main" {
  # We are NOT creating a new Organization —
  # Organization r-iaiz already exists
  # This resource IMPORTS and MANAGES the existing one
  # Run: terraform import aws_organizations_organization.main r-iaiz

  aws_service_access_principals = var.enable_aws_service_access

  # ALL_FEATURES enables SCPs, tag policies, and all
  # Organization governance capabilities
  # CONSOLIDATED_BILLING_ONLY would not allow SCPs
  feature_set = "ALL"

  # Enable these policy types org-wide
  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY", # Our SCPs
    "TAG_POLICY",             # Tag governance enforcement
    "BACKUP_POLICY",          # Backup compliance enforcement
  ]
}

# -----------------------------------------------------------
# ORGANIZATIONAL UNITS
# The folder structure grouping accounts by purpose
# Each OU will have different SCPs applied to it
# reflecting the risk level of the workloads inside
#
# OU Structure:
#   Root (r-iaiz)
#   ├── Security OU         → Security Tooling + Log Archive
#   ├── Production OU       → PCI-CDE + Core Banking
#   ├── Non-Production OU   → Dev + QA/Staging
#   ├── Pipeline OU         → CI-CD + Terraform
#   └── Compliance OU       → Audit account only
# -----------------------------------------------------------
resource "aws_organizations_organizational_unit" "security" {
  count     = var.create_security_ou ? 1 : 0
  name      = "Security"
  parent_id = aws_organizations_organization.main.roots[0].id

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-ou-security"
    Purpose = "Security tooling and log archive accounts"
    SCPs    = "Strictest controls - security tools must not be disabled"
  })
}

resource "aws_organizations_organizational_unit" "production" {
  count     = var.create_production_ou ? 1 : 0
  name      = "Production"
  parent_id = aws_organizations_organization.main.roots[0].id

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-ou-production"
    Purpose = "Production workload accounts - PCI-CDE / Core Banking"
    SCPs    = "Strictest controls - no console access and all actions logged"
  })
}

resource "aws_organizations_organizational_unit" "non_production" {
  count     = var.create_non_production_ou ? 1 : 0
  name      = "NonProduction"
  parent_id = aws_organizations_organization.main.roots[0].id

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-ou-non-production"
    Purpose = "Dev and QA accounts - relaxed SCPs for engineer access"
    SCPs    = "Relaxed - engineers need more flexibility for development"
  })
}

resource "aws_organizations_organizational_unit" "pipeline" {
  count     = var.create_pipeline_ou ? 1 : 0
  name      = "Pipeline"
  parent_id = aws_organizations_organization.main.roots[0].id

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-ou-pipeline"
    Purpose = "CI-CD accounts - Terraform Cloud / Checkov / SAST"
    SCPs    = "Assume-role only - pipeline assumes roles into target accounts"
  })
}

resource "aws_organizations_organizational_unit" "compliance" {
  count     = var.create_compliance_ou ? 1 : 0
  name      = "Compliance"
  parent_id = aws_organizations_organization.main.roots[0].id

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-ou-compliance"
    Purpose = "Audit account - OCC examiner read-only access"
    SCPs    = "DenyAllWrites - this OU can only READ and never modify"
  })
}

# -----------------------------------------------------------
# EXISTING ACCOUNT OU PLACEMENT
# Move existing accounts into correct OUs
# These accounts already exist — we are only managing
# their organizational membership
# -----------------------------------------------------------
resource "aws_organizations_account" "security_tooling" {
  # This does NOT create a new account
  # It references the existing Security Tooling account
  # and ensures it is in the Security OU
  # Run: terraform import aws_organizations_account.security_tooling 368351959735

  name      = "Amex-Security-Tooling"
  email     = "abuhariconsultingservicesllc@gmail.com"
  parent_id = var.create_security_ou ? aws_organizations_organizational_unit.security[0].id : aws_organizations_organization.main.roots[0].id

  # Prevent accidental account deletion via Terraform
  lifecycle {
    prevent_destroy = true
    # Ignore changes to role_name — AWS manages this
    ignore_changes = [role_name, iam_user_access_to_billing]
  }

  tags = merge(var.common_tags, {
    Name        = "Amex-Security-Tooling"
    AccountType = "SecurityTooling"
    Environment = "Production"
  })
}

# -----------------------------------------------------------
# NEW ACCOUNT CREATION
# Each account is gated by a toggle variable
# Defaults to false — must be explicitly enabled
# WARNING: account creation is permanent
# -----------------------------------------------------------
resource "aws_organizations_account" "audit" {
  count = var.create_audit_account ? 1 : 0

  name      = "Amex-Audit"
  email     = var.audit_account_email
  parent_id = var.create_compliance_ou ? aws_organizations_organizational_unit.compliance[0].id : aws_organizations_organization.main.roots[0].id

  # Audit account must NEVER have IAM billing access
  # OCC examiners should not have financial visibility
  iam_user_access_to_billing = "DENY"

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [role_name, iam_user_access_to_billing]
  }

  tags = merge(var.common_tags, {
    Name        = "Amex-Audit"
    AccountType = "Audit"
    Environment = "Compliance"
    Purpose     = "OCC examiner and internal audit read-only access"
  })
}

resource "aws_organizations_account" "pci_cde" {
  count = var.create_pci_cde_account ? 1 : 0

  name      = "Amex-PCI-CDE"
  email     = var.pci_cde_account_email
  parent_id = var.create_production_ou ? aws_organizations_organizational_unit.production[0].id : aws_organizations_organization.main.roots[0].id

  iam_user_access_to_billing = "DENY"

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [role_name, iam_user_access_to_billing]
  }

  tags = merge(var.common_tags, {
    Name            = "Amex-PCI-CDE"
    AccountType     = "Workload"
    Environment     = "Production"
    ComplianceScope = "PCI-DSS-v4-CDE"
    DataClass       = "Restricted-CardholderData"
  })
}

resource "aws_organizations_account" "core_banking" {
  count = var.create_core_banking_account ? 1 : 0

  name      = "Amex-Core-Banking"
  email     = var.core_banking_account_email
  parent_id = var.create_production_ou ? aws_organizations_organizational_unit.production[0].id : aws_organizations_organization.main.roots[0].id

  iam_user_access_to_billing = "DENY"

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [role_name, iam_user_access_to_billing]
  }

  tags = merge(var.common_tags, {
    Name        = "Amex-Core-Banking"
    AccountType = "Workload"
    Environment = "Production"
    DataClass   = "Restricted-FinancialData"
  })
}

resource "aws_organizations_account" "dev" {
  count = var.create_dev_account ? 1 : 0

  name      = "Amex-Dev"
  email     = var.dev_account_email
  parent_id = var.create_non_production_ou ? aws_organizations_organizational_unit.non_production[0].id : aws_organizations_organization.main.roots[0].id

  iam_user_access_to_billing = "DENY"

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [role_name, iam_user_access_to_billing]
  }

  tags = merge(var.common_tags, {
    Name        = "Amex-Dev"
    AccountType = "Workload"
    Environment = "NonProduction"
    DataClass   = "Internal"
  })
}

resource "aws_organizations_account" "pipeline" {
  count = var.create_pipeline_account ? 1 : 0

  name      = "Amex-Pipeline-CICD"
  email     = var.pipeline_account_email
  parent_id = var.create_pipeline_ou ? aws_organizations_organizational_unit.pipeline[0].id : aws_organizations_organization.main.roots[0].id

  iam_user_access_to_billing = "DENY"

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [role_name, iam_user_access_to_billing]
  }

  tags = merge(var.common_tags, {
    Name        = "Amex-Pipeline-CICD"
    AccountType = "Pipeline"
    Environment = "NonProduction"
    Purpose     = "Terraform Cloud + Checkov + SAST scanning"
  })
}

# -----------------------------------------------------------
# FRAUD DETECTION ACCOUNT — ML fraud scoring (Production OU)
# Hosts SageMaker endpoints for real-time fraud detection
# LBB-FraudEngine workload deployed here
# -----------------------------------------------------------
resource "aws_organizations_account" "fraud_detection" {
  count     = var.create_fraud_detection_account ? 1 : 0
  name      = "Amex-Fraud-Detection"
  email     = var.fraud_detection_account_email
  parent_id = var.create_production_ou ? aws_organizations_organizational_unit.production[0].id : aws_organizations_organization.main.roots[0].id

  iam_user_access_to_billing = "DENY"

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [role_name, iam_user_access_to_billing]
  }

  tags = merge(var.common_tags, {
    Name         = "Amex-Fraud-Detection"
    AccountType  = "Workload"
    BusinessUnit = "Risk-Management"
    Workload     = "LBB-FraudEngine"
    DataClass    = "Confidential"
    Environment  = "Production"
  })
}

# -----------------------------------------------------------
# CUSTOMER PORTAL ACCOUNT — banking portal (Production OU)
# Customer-facing web application
# LBB-BankingPortal workload deployed here
# -----------------------------------------------------------
resource "aws_organizations_account" "customer_portal" {
  count     = var.create_customer_portal_account ? 1 : 0
  name      = "Amex-Customer-Portal"
  email     = var.customer_portal_account_email
  parent_id = var.create_production_ou ? aws_organizations_organizational_unit.production[0].id : aws_organizations_organization.main.roots[0].id

  iam_user_access_to_billing = "DENY"

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [role_name, iam_user_access_to_billing]
  }

  tags = merge(var.common_tags, {
    Name         = "Amex-Customer-Portal"
    AccountType  = "Workload"
    BusinessUnit = "Consumer-Banking"
    Workload     = "LBB-BankingPortal"
    DataClass    = "Confidential"
    Environment  = "Production"
  })
}

# -----------------------------------------------------------
# DATA ANALYTICS ACCOUNT — data lake + reporting (Production OU)
# Data lake, regulatory reporting, ML training data
# LBB-RegReporting workload deployed here
# -----------------------------------------------------------
resource "aws_organizations_account" "data_analytics" {
  count     = var.create_data_analytics_account ? 1 : 0
  name      = "Amex-Data-Analytics"
  email     = var.data_analytics_account_email
  parent_id = var.create_production_ou ? aws_organizations_organizational_unit.production[0].id : aws_organizations_organization.main.roots[0].id

  iam_user_access_to_billing = "DENY"

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [role_name, iam_user_access_to_billing]
  }

  tags = merge(var.common_tags, {
    Name         = "Amex-Data-Analytics"
    AccountType  = "Workload"
    BusinessUnit = "Enterprise-Technology"
    Workload     = "LBB-RegReporting"
    DataClass    = "Confidential"
    Environment  = "Production"
  })
}

# -----------------------------------------------------------
# BI REPORTING ACCOUNT — compliance dashboards (Production OU)
# Power BI dashboards, QuickSight, executive reporting
# LBB-BI workload deployed here
# -----------------------------------------------------------
resource "aws_organizations_account" "bi_reporting" {
  count     = var.create_bi_reporting_account ? 1 : 0
  name      = "Amex-BI-Reporting"
  email     = var.bi_reporting_account_email
  parent_id = var.create_production_ou ? aws_organizations_organizational_unit.production[0].id : aws_organizations_organization.main.roots[0].id

  iam_user_access_to_billing = "DENY"

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [role_name, iam_user_access_to_billing]
  }

  tags = merge(var.common_tags, {
    Name         = "Amex-BI-Reporting"
    AccountType  = "Workload"
    BusinessUnit = "Enterprise-Technology"
    Workload     = "LBB-BI"
    DataClass    = "Internal"
    Environment  = "Production"
  })
}

# -----------------------------------------------------------
# DELEGATED ADMINISTRATOR CONFIGURATION
# Designates Security Tooling as the admin for security
# services org-wide. Once delegated:
#   GuardDuty in Security Tooling sees ALL accounts
#   Security Hub aggregates findings from ALL accounts
#   Detective graph spans ALL accounts
#   New accounts auto-enroll when added to the org
#
# IMPORTANT: The delegated service must already be enabled
# in the Security Tooling account before delegation works
#
# WHAT DELEGATION ACTUALLY GRANTS:
# Each resource below grants Security Tooling org-wide REACH for
# ONE service only — e.g. GuardDuty delegation lets Security Tooling
# call GuardDuty APIs against every account (PCI-CDE, Core Banking,
# Dev, Pipeline, Compliance), but NOT S3/IAM/EC2 APIs in those accounts.
# It is narrow in scope (one service), broad in reach (all accounts).
# Six independent grants — enabling one does not widen another.
# -----------------------------------------------------------
resource "aws_organizations_delegated_administrator" "guardduty" {
  count             = var.enable_guardduty_delegated_admin ? 1 : 0
  account_id        = var.security_tooling_account_id
  service_principal = "guardduty.amazonaws.com"

  depends_on = [aws_organizations_organization.main]
}

resource "aws_organizations_delegated_administrator" "securityhub" {
  count             = var.enable_securityhub_delegated_admin ? 1 : 0
  account_id        = var.security_tooling_account_id
  service_principal = "securityhub.amazonaws.com"

  depends_on = [aws_organizations_organization.main]
}

# Security Hub, unlike GuardDuty, does not recognize an account as its
# organization admin just from the generic Organizations delegated-admin
# registration above. It requires its own EnableOrganizationAdminAccount
# call — without this, aws_securityhub_organization_configuration in the
# security-hub module fails with "InvalidAccessException: Account ... is
# not an administrator for this organization" even though
# list-delegated-administrators shows it as ACTIVE.
resource "aws_securityhub_organization_admin_account" "main" {
  count            = var.enable_securityhub_delegated_admin ? 1 : 0
  admin_account_id = var.security_tooling_account_id

  depends_on = [aws_organizations_delegated_administrator.securityhub]
}

resource "aws_organizations_delegated_administrator" "detective" {
  count             = var.enable_detective_delegated_admin ? 1 : 0
  account_id        = var.security_tooling_account_id
  service_principal = "detective.amazonaws.com"

  depends_on = [aws_organizations_organization.main]
}

resource "aws_organizations_delegated_administrator" "config" {
  count             = var.enable_config_delegated_admin ? 1 : 0
  account_id        = var.security_tooling_account_id
  service_principal = "config.amazonaws.com"

  depends_on = [aws_organizations_organization.main]
}

resource "aws_organizations_delegated_administrator" "macie" {
  count             = var.enable_macie_delegated_admin ? 1 : 0
  account_id        = var.security_tooling_account_id
  service_principal = "macie.amazonaws.com"

  depends_on = [aws_organizations_organization.main]
}

resource "aws_organizations_delegated_administrator" "backup" {
  count             = var.enable_backup_delegated_admin ? 1 : 0
  account_id        = var.security_tooling_account_id
  service_principal = "backup.amazonaws.com"

  depends_on = [aws_organizations_organization.main]
}
