# ============================================================
# variables.tf — Entra ID Enterprise Applications & SSO
# Module: entra-id-apps
#
# WHAT THIS MODULE BUILDS:
# Enterprise application registrations in Microsoft Entra ID
# for all LBB banking applications with SAML 2.0 SSO,
# OAuth 2.0 API authentication, group-based access control,
# and Conditional Access policies.
#
# DEPLOYMENT: Microsoft Entra ID (Azure AD)
# TENANT: 288a15d1-700c-482b-a591-7c1d4e6c4f3c
# ============================================================

variable "tenant_id" {
  description = "Microsoft Entra ID tenant ID."
  type        = string
  default     = "288a15d1-700c-482b-a591-7c1d4e6c4f3c"
}

variable "enable_entra_apps" {
  description = "Enable Entra ID enterprise application registrations."
  type        = bool
  default     = false
}

variable "enable_conditional_access" {
  description = "Enable Conditional Access policies. Requires Entra ID P1 or P2 license."
  type        = bool
  default     = false
}

# -----------------------------------------------------------
# BUSINESS UNIT GROUPS
# -----------------------------------------------------------
variable "business_unit_groups" {
  description = "Business unit groups — one per department."
  type = list(object({
    name        = string
    description = string
    members     = list(string)
  }))
  default = [
    {
      name        = "BU-Card-Processing"
      description = "PCI-CDE team — card authorization and tokenization"
      members     = []
    },
    {
      name        = "BU-Core-Banking"
      description = "Payment services team — transfers, bill pay, wires"
      members     = []
    },
    {
      name        = "BU-Fraud-Detection"
      description = "Data science and fraud analytics team"
      members     = []
    },
    {
      name        = "BU-Customer-Portal"
      description = "Frontend engineering — customer-facing banking app"
      members     = []
    },
    {
      name        = "BU-Compliance"
      description = "Regulatory, risk, and compliance team"
      members     = []
    },
    {
      name        = "BU-Security"
      description = "SOC, security engineering, and threat intelligence"
      members     = []
    },
    {
      name        = "BU-Executive"
      description = "CISO, CTO, board members — dashboard access only"
      members     = []
    }
  ]
}

# -----------------------------------------------------------
# APPLICATION ROLE GROUPS
# -----------------------------------------------------------
variable "role_groups" {
  description = "Role-based groups mapped to application permissions."
  type = list(object({
    name        = string
    description = string
  }))
  default = [
    {
      name        = "Role-App-Admin"
      description = "Full application administration — config changes, user management"
    },
    {
      name        = "Role-App-ReadOnly"
      description = "View dashboards, reports, and findings — no write access"
    },
    {
      name        = "Role-App-Operator"
      description = "Run transactions, process payments, execute workflows"
    },
    {
      name        = "Role-App-Developer"
      description = "Dev and test environment access — no production"
    },
    {
      name        = "Role-App-Auditor"
      description = "OCC examiner and internal audit — read-only across all apps"
    }
  ]
}

# -----------------------------------------------------------
# ENTERPRISE APPLICATIONS (SAML 2.0 SSO)
# -----------------------------------------------------------
variable "saml_applications" {
  description = "Applications with SAML 2.0 SSO for browser-based access."
  type = list(object({
    name             = string
    description      = string
    identifier_uri   = string
    reply_url        = string
    logout_url       = string
    assigned_groups  = list(string)
    session_timeout  = number
  }))
  default = [
    {
      name            = "LBB-BankingPortal"
      description     = "Customer-facing banking application"
      identifier_uri  = "https://banking.boa-amex.com"
      reply_url       = "https://banking.boa-amex.com/auth/saml/callback"
      logout_url      = "https://banking.boa-amex.com/auth/logout"
      assigned_groups = ["BU-Customer-Portal", "BU-Core-Banking", "BU-Executive", "Role-App-Operator"]
      session_timeout = 30
    },
    {
      name            = "LBB-BI-Dashboard"
      description     = "Executive compliance and security dashboards"
      identifier_uri  = "https://bi.boa-amex.com"
      reply_url       = "https://bi.boa-amex.com/auth/saml/callback"
      logout_url      = "https://bi.boa-amex.com/auth/logout"
      assigned_groups = ["BU-Executive", "BU-Compliance", "BU-Security", "Role-App-ReadOnly"]
      session_timeout = 60
    },
    {
      name            = "LBB-RegReporting"
      description     = "Regulatory reporting — OCC, PCI-DSS, BSA/AML"
      identifier_uri  = "https://reporting.boa-amex.com"
      reply_url       = "https://reporting.boa-amex.com/auth/saml/callback"
      logout_url      = "https://reporting.boa-amex.com/auth/logout"
      assigned_groups = ["BU-Compliance", "BU-Executive", "Role-App-Auditor"]
      session_timeout = 30
    },
    {
      name            = "LBB-Scheduler"
      description     = "Internal scheduling and operations platform"
      identifier_uri  = "https://scheduler.boa-amex.com"
      reply_url       = "https://scheduler.boa-amex.com/auth/saml/callback"
      logout_url      = "https://scheduler.boa-amex.com/auth/logout"
      assigned_groups = ["BU-Core-Banking", "BU-Customer-Portal", "Role-App-Operator"]
      session_timeout = 60
    },
    {
      name            = "LBB-SecurityCopilot"
      description     = "AI-powered security investigation console"
      identifier_uri  = "https://copilot.boa-amex.com"
      reply_url       = "https://copilot.boa-amex.com/auth/saml/callback"
      logout_url      = "https://copilot.boa-amex.com/auth/logout"
      assigned_groups = ["BU-Security", "Role-App-Admin"]
      session_timeout = 15
    }
  ]
}

# -----------------------------------------------------------
# API REGISTRATIONS (OAuth 2.0 client credentials)
# -----------------------------------------------------------
variable "api_applications" {
  description = "API applications with OAuth 2.0 client credentials for service-to-service auth."
  type = list(object({
    name             = string
    description      = string
    api_identifier   = string
    permissions      = list(string)
    allowed_clients  = list(string)
  }))
  default = [
    {
      name            = "LBB-CardAuth-API"
      description     = "Card authorization service API — tokenization and scoring"
      api_identifier  = "api://lbb-card-auth"
      permissions     = ["Transaction.Authorize", "Token.Create", "Token.Read"]
      allowed_clients = ["LBB-BankingPortal", "LBB-PaymentService-API"]
    },
    {
      name            = "LBB-PaymentService-API"
      description     = "Payment service API — transfers, bill pay, wires"
      api_identifier  = "api://lbb-payment-service"
      permissions     = ["Transfer.Execute", "BillPay.Execute", "Wire.Execute", "Transaction.Read"]
      allowed_clients = ["LBB-BankingPortal", "LBB-RegReporting-API"]
    },
    {
      name            = "LBB-FraudEngine-API"
      description     = "Fraud scoring API — ML-based transaction scoring"
      api_identifier  = "api://lbb-fraud-engine"
      permissions     = ["FraudScore.Read", "FraudCase.Read", "FraudCase.Update", "Model.Metrics"]
      allowed_clients = ["LBB-CardAuth-API", "LBB-BI-API"]
    },
    {
      name            = "LBB-RegReporting-API"
      description     = "Regulatory reporting API — compliance reports"
      api_identifier  = "api://lbb-reg-reporting"
      permissions     = ["Report.Generate", "Report.Read", "Compliance.Score"]
      allowed_clients = ["LBB-BI-API"]
    },
    {
      name            = "LBB-BI-API"
      description     = "BI dashboard API — executive and SOC dashboards"
      api_identifier  = "api://lbb-bi"
      permissions     = ["Dashboard.Read", "Metrics.Read"]
      allowed_clients = ["LBB-BankingPortal"]
    }
  ]
}

# -----------------------------------------------------------
# CONDITIONAL ACCESS
# -----------------------------------------------------------
variable "pci_apps" {
  description = "Applications requiring PCI-level Conditional Access (MFA + compliant device + 15-min timeout)."
  type        = list(string)
  default     = ["LBB-CardAuth-API", "LBB-PaymentService-API", "LBB-BankingPortal"]
}

variable "trusted_locations" {
  description = "Trusted IP ranges for Conditional Access."
  type        = list(string)
  default     = ["10.0.0.0/8", "172.16.0.0/12"]
}

variable "common_tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default = {
    Project    = "BOA-AMEX-TechResolved"
    Owner      = "Eliud-Maina"
    Consultant = "Abuhari-Consulting-Services"
    ManagedBy  = "Terraform"
    Module     = "entra-id-apps"
  }
}
