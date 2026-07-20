# ============================================================
# main.tf — Cross-account audit read-only roles
# Module: audit-account
#
# WHAT THIS FILE DOES:
# Creates IAM roles in each AWS account that trust the
# Audit account (445459853572). OCC examiners assume these
# roles from the Audit account to inspect each account.
#
# PROVIDER ALIASES:
# This module uses multiple provider aliases — one per
# account. The Management environment passes these in
# when calling the module.
#
# ROLE TRUST RELATIONSHIP:
# Each role trusts: arn:aws:iam::445459853572:root
# This means: anyone authenticated in the Audit account
# can assume this role (subject to their own permissions)
#
# ROLE PERMISSIONS:
# SecurityAudit (AWS managed) — read security configurations
# ViewOnlyAccess (AWS managed) — read all resource configs
# Combined: complete read-only visibility, zero write access
# ============================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      configuration_aliases = [
        aws.management,
        aws.security_tooling,
        aws.pci_cde,
        aws.core_banking,
        aws.dev,
        aws.pipeline,
        aws.fraud_detection,
        aws.customer_portal,
        aws.data_analytics,
        aws.bi_reporting
      ]
    }
  }
}

# -----------------------------------------------------------
# AUDIT ROLE IN MANAGEMENT ACCOUNT
# Allows OCC examiners to review:
#   SCPs, Organization structure, CloudTrail config
#   IAM policies, Config aggregator, billing data
# -----------------------------------------------------------
resource "aws_iam_role" "audit_readonly_management" {
  count    = var.create_management_audit_role ? 1 : 0
  provider = aws.management

  name                 = var.audit_role_name
  description          = var.audit_role_description
  max_session_duration = var.max_session_duration

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAuditAccountAssumption"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.audit_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "BOA-AMEX-OCC-AUDIT"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.project_prefix}-audit-readonly-management"
    AccountType = "Management"
    Purpose     = "OCC examiner read-only access to Management account"
  })
}

resource "aws_iam_role_policy_attachment" "audit_management_security" {
  count      = var.create_management_audit_role ? 1 : 0
  provider   = aws.management
  role       = aws_iam_role.audit_readonly_management[0].name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "aws_iam_role_policy_attachment" "audit_management_viewonly" {
  count      = var.create_management_audit_role ? 1 : 0
  provider   = aws.management
  role       = aws_iam_role.audit_readonly_management[0].name
  policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
}

# -----------------------------------------------------------
# AUDIT ROLE IN SECURITY TOOLING ACCOUNT
# Allows OCC examiners to review:
#   GuardDuty findings, Security Hub findings
#   CloudTrail logs, Config compliance status
#   Detective graph (behavioral analysis)
#   SOAR Lambda functions and EventBridge rules
# -----------------------------------------------------------
resource "aws_iam_role" "audit_readonly_security_tooling" {
  count    = var.create_security_tooling_audit_role ? 1 : 0
  provider = aws.security_tooling

  name                 = var.audit_role_name
  description          = var.audit_role_description
  max_session_duration = var.max_session_duration

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAuditAccountAssumption"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.audit_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "BOA-AMEX-OCC-AUDIT"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.project_prefix}-audit-readonly-security-tooling"
    AccountType = "SecurityTooling"
    Purpose     = "OCC examiner read-only access to Security Tooling account"
  })
}

resource "aws_iam_role_policy_attachment" "audit_security_tooling_security" {
  count      = var.create_security_tooling_audit_role ? 1 : 0
  provider   = aws.security_tooling
  role       = aws_iam_role.audit_readonly_security_tooling[0].name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "aws_iam_role_policy_attachment" "audit_security_tooling_viewonly" {
  count      = var.create_security_tooling_audit_role ? 1 : 0
  provider   = aws.security_tooling
  role       = aws_iam_role.audit_readonly_security_tooling[0].name
  policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
}

# -----------------------------------------------------------
# AUDIT ROLES IN WORKLOAD ACCOUNTS
# Same read-only pattern as Management/Security Tooling above,
# extended to every workload account so OCC examiners can
# actually reach the accounts they're auditing. customer_portal
# is excluded by default — that account doesn't exist yet
# (AWS Organizations account limit reached).
# -----------------------------------------------------------
resource "aws_iam_role" "audit_readonly_pci_cde" {
  count    = var.create_pci_cde_audit_role ? 1 : 0
  provider = aws.pci_cde

  name                 = var.audit_role_name
  description          = var.audit_role_description
  max_session_duration = var.max_session_duration

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAuditAccountAssumption"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.audit_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "BOA-AMEX-OCC-AUDIT"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.project_prefix}-audit-readonly-pci-cde"
    AccountType = "Workload"
    Purpose     = "OCC examiner read-only access to PCI-CDE account"
  })
}

resource "aws_iam_role_policy_attachment" "audit_pci_cde_security" {
  count      = var.create_pci_cde_audit_role ? 1 : 0
  provider   = aws.pci_cde
  role       = aws_iam_role.audit_readonly_pci_cde[0].name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "aws_iam_role_policy_attachment" "audit_pci_cde_viewonly" {
  count      = var.create_pci_cde_audit_role ? 1 : 0
  provider   = aws.pci_cde
  role       = aws_iam_role.audit_readonly_pci_cde[0].name
  policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
}

resource "aws_iam_role" "audit_readonly_core_banking" {
  count    = var.create_core_banking_audit_role ? 1 : 0
  provider = aws.core_banking

  name                 = var.audit_role_name
  description          = var.audit_role_description
  max_session_duration = var.max_session_duration

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAuditAccountAssumption"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.audit_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "BOA-AMEX-OCC-AUDIT"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.project_prefix}-audit-readonly-core-banking"
    AccountType = "Workload"
    Purpose     = "OCC examiner read-only access to Core Banking account"
  })
}

resource "aws_iam_role_policy_attachment" "audit_core_banking_security" {
  count      = var.create_core_banking_audit_role ? 1 : 0
  provider   = aws.core_banking
  role       = aws_iam_role.audit_readonly_core_banking[0].name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "aws_iam_role_policy_attachment" "audit_core_banking_viewonly" {
  count      = var.create_core_banking_audit_role ? 1 : 0
  provider   = aws.core_banking
  role       = aws_iam_role.audit_readonly_core_banking[0].name
  policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
}

resource "aws_iam_role" "audit_readonly_dev" {
  count    = var.create_dev_audit_role ? 1 : 0
  provider = aws.dev

  name                 = var.audit_role_name
  description          = var.audit_role_description
  max_session_duration = var.max_session_duration

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAuditAccountAssumption"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.audit_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "BOA-AMEX-OCC-AUDIT"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.project_prefix}-audit-readonly-dev"
    AccountType = "Workload"
    Purpose     = "OCC examiner read-only access to Dev account"
  })
}

resource "aws_iam_role_policy_attachment" "audit_dev_security" {
  count      = var.create_dev_audit_role ? 1 : 0
  provider   = aws.dev
  role       = aws_iam_role.audit_readonly_dev[0].name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "aws_iam_role_policy_attachment" "audit_dev_viewonly" {
  count      = var.create_dev_audit_role ? 1 : 0
  provider   = aws.dev
  role       = aws_iam_role.audit_readonly_dev[0].name
  policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
}

resource "aws_iam_role" "audit_readonly_pipeline" {
  count    = var.create_pipeline_audit_role ? 1 : 0
  provider = aws.pipeline

  name                 = var.audit_role_name
  description          = var.audit_role_description
  max_session_duration = var.max_session_duration

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAuditAccountAssumption"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.audit_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "BOA-AMEX-OCC-AUDIT"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.project_prefix}-audit-readonly-pipeline"
    AccountType = "Workload"
    Purpose     = "OCC examiner read-only access to Pipeline/CI-CD account"
  })
}

resource "aws_iam_role_policy_attachment" "audit_pipeline_security" {
  count      = var.create_pipeline_audit_role ? 1 : 0
  provider   = aws.pipeline
  role       = aws_iam_role.audit_readonly_pipeline[0].name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "aws_iam_role_policy_attachment" "audit_pipeline_viewonly" {
  count      = var.create_pipeline_audit_role ? 1 : 0
  provider   = aws.pipeline
  role       = aws_iam_role.audit_readonly_pipeline[0].name
  policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
}

resource "aws_iam_role" "audit_readonly_fraud_detection" {
  count    = var.create_fraud_detection_audit_role ? 1 : 0
  provider = aws.fraud_detection

  name                 = var.audit_role_name
  description          = var.audit_role_description
  max_session_duration = var.max_session_duration

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAuditAccountAssumption"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.audit_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "BOA-AMEX-OCC-AUDIT"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.project_prefix}-audit-readonly-fraud-detection"
    AccountType = "Workload"
    Purpose     = "OCC examiner read-only access to Fraud Detection account"
  })
}

resource "aws_iam_role_policy_attachment" "audit_fraud_detection_security" {
  count      = var.create_fraud_detection_audit_role ? 1 : 0
  provider   = aws.fraud_detection
  role       = aws_iam_role.audit_readonly_fraud_detection[0].name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "aws_iam_role_policy_attachment" "audit_fraud_detection_viewonly" {
  count      = var.create_fraud_detection_audit_role ? 1 : 0
  provider   = aws.fraud_detection
  role       = aws_iam_role.audit_readonly_fraud_detection[0].name
  policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
}

resource "aws_iam_role" "audit_readonly_customer_portal" {
  count    = var.create_customer_portal_audit_role ? 1 : 0
  provider = aws.customer_portal

  name                 = var.audit_role_name
  description          = var.audit_role_description
  max_session_duration = var.max_session_duration

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAuditAccountAssumption"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.audit_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "BOA-AMEX-OCC-AUDIT"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.project_prefix}-audit-readonly-customer-portal"
    AccountType = "Workload"
    Purpose     = "OCC examiner read-only access to Customer Portal account"
  })
}

resource "aws_iam_role_policy_attachment" "audit_customer_portal_security" {
  count      = var.create_customer_portal_audit_role ? 1 : 0
  provider   = aws.customer_portal
  role       = aws_iam_role.audit_readonly_customer_portal[0].name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "aws_iam_role_policy_attachment" "audit_customer_portal_viewonly" {
  count      = var.create_customer_portal_audit_role ? 1 : 0
  provider   = aws.customer_portal
  role       = aws_iam_role.audit_readonly_customer_portal[0].name
  policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
}

resource "aws_iam_role" "audit_readonly_data_analytics" {
  count    = var.create_data_analytics_audit_role ? 1 : 0
  provider = aws.data_analytics

  name                 = var.audit_role_name
  description          = var.audit_role_description
  max_session_duration = var.max_session_duration

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAuditAccountAssumption"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.audit_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "BOA-AMEX-OCC-AUDIT"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.project_prefix}-audit-readonly-data-analytics"
    AccountType = "Workload"
    Purpose     = "OCC examiner read-only access to Data Analytics account"
  })
}

resource "aws_iam_role_policy_attachment" "audit_data_analytics_security" {
  count      = var.create_data_analytics_audit_role ? 1 : 0
  provider   = aws.data_analytics
  role       = aws_iam_role.audit_readonly_data_analytics[0].name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "aws_iam_role_policy_attachment" "audit_data_analytics_viewonly" {
  count      = var.create_data_analytics_audit_role ? 1 : 0
  provider   = aws.data_analytics
  role       = aws_iam_role.audit_readonly_data_analytics[0].name
  policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
}

resource "aws_iam_role" "audit_readonly_bi_reporting" {
  count    = var.create_bi_reporting_audit_role ? 1 : 0
  provider = aws.bi_reporting

  name                 = var.audit_role_name
  description          = var.audit_role_description
  max_session_duration = var.max_session_duration

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAuditAccountAssumption"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.audit_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "BOA-AMEX-OCC-AUDIT"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.project_prefix}-audit-readonly-bi-reporting"
    AccountType = "Workload"
    Purpose     = "OCC examiner read-only access to BI Reporting account"
  })
}

resource "aws_iam_role_policy_attachment" "audit_bi_reporting_security" {
  count      = var.create_bi_reporting_audit_role ? 1 : 0
  provider   = aws.bi_reporting
  role       = aws_iam_role.audit_readonly_bi_reporting[0].name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "aws_iam_role_policy_attachment" "audit_bi_reporting_viewonly" {
  count      = var.create_bi_reporting_audit_role ? 1 : 0
  provider   = aws.bi_reporting
  role       = aws_iam_role.audit_readonly_bi_reporting[0].name
  policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
}

# -----------------------------------------------------------
# AUDIT ACCOUNT TRUST POLICY
# In the Audit account itself — allows OCCExaminer
# Permission Set users to assume roles in other accounts
# -----------------------------------------------------------
resource "aws_iam_policy" "assume_audit_roles" {
  provider = aws.management

  name        = "${var.project_prefix}-assume-audit-roles"
  description = "Allows assuming AuditReadOnly role in all accounts. Attached to OCCExaminer Permission Set boundary."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAssumeAuditRoles"
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = compact([
          "arn:aws:iam::${var.management_account_id}:role/${var.audit_role_name}",
          "arn:aws:iam::${var.security_tooling_account_id}:role/${var.audit_role_name}",
          var.pci_cde_account_id != "" ? "arn:aws:iam::${var.pci_cde_account_id}:role/${var.audit_role_name}" : "",
          var.core_banking_account_id != "" ? "arn:aws:iam::${var.core_banking_account_id}:role/${var.audit_role_name}" : "",
          var.dev_account_id != "" ? "arn:aws:iam::${var.dev_account_id}:role/${var.audit_role_name}" : "",
          var.pipeline_account_id != "" ? "arn:aws:iam::${var.pipeline_account_id}:role/${var.audit_role_name}" : "",
          var.fraud_detection_account_id != "" ? "arn:aws:iam::${var.fraud_detection_account_id}:role/${var.audit_role_name}" : "",
          var.customer_portal_account_id != "" ? "arn:aws:iam::${var.customer_portal_account_id}:role/${var.audit_role_name}" : "",
          var.data_analytics_account_id != "" ? "arn:aws:iam::${var.data_analytics_account_id}:role/${var.audit_role_name}" : "",
          var.bi_reporting_account_id != "" ? "arn:aws:iam::${var.bi_reporting_account_id}:role/${var.audit_role_name}" : "",
        ])
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "BOA-AMEX-OCC-AUDIT"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-assume-audit-roles"
    Purpose = "Allows OCCExaminer to pivot from Audit account into all other accounts"
  })
}