# ============================================================
# main.tf — Entra ID Enterprise Applications & SSO
# Module: entra-id-apps
#
# Creates enterprise application registrations in Entra ID
# for all LBB banking applications with:
#   SAML 2.0 SSO for web applications
#   OAuth 2.0 client credentials for API authentication
#   Group-based access control (business unit + role)
#   Conditional Access policies
#
# PROVIDER: azuread (Microsoft Entra ID / Azure AD)
# TENANT: 288a15d1-700c-482b-a591-7c1d4e6c4f3c
#
# NOTE: Requires Azure AD / Entra ID provider configured.
# Azure subscription is currently DISABLED — this module
# defines the configuration for when it's restored.
# ============================================================

terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47"
    }
  }
}

data "azuread_client_config" "current" {
  count = var.enable_entra_apps ? 1 : 0
}

# ═══════════════════════════════════════════════════════════
# BUSINESS UNIT GROUPS
# One group per department — controls who can access what
# ═══════════════════════════════════════════════════════════

resource "azuread_group" "business_units" {
  for_each = var.enable_entra_apps ? {
    for g in var.business_unit_groups : g.name => g
  } : {}

  display_name     = each.value.name
  description      = each.value.description
  security_enabled = true
  mail_enabled     = false

  # Groups are dynamic in production (populated by HR feed)
  # Static members for demo/dev
}

# ═══════════════════════════════════════════════════════════
# ROLE GROUPS
# Cross-cutting roles mapped to application permissions
# ═══════════════════════════════════════════════════════════

resource "azuread_group" "roles" {
  for_each = var.enable_entra_apps ? {
    for g in var.role_groups : g.name => g
  } : {}

  display_name     = each.value.name
  description      = each.value.description
  security_enabled = true
  mail_enabled     = false
}

# ═══════════════════════════════════════════════════════════
# SAML ENTERPRISE APPLICATIONS — web SSO
# Each LBB web application gets a SAML 2.0 integration
# ═══════════════════════════════════════════════════════════

resource "azuread_application" "saml_apps" {
  for_each = var.enable_entra_apps ? {
    for app in var.saml_applications : app.name => app
  } : {}

  display_name = each.value.name
  description  = each.value.description

  identifier_uris = [each.value.identifier_uri]

  web {
    redirect_uris = [each.value.reply_url]
    logout_url    = each.value.logout_url

    implicit_grant {
      id_token_issuance_enabled = true
    }
  }

  # SAML claims mapping
  group_membership_claims = ["SecurityGroup"]

  optional_claims {
    saml2_token {
      name = "groups"
    }
    saml2_token {
      name = "email"
    }
    saml2_token {
      name = "given_name"
    }
    saml2_token {
      name = "family_name"
    }
    saml2_token {
      name = "department"
    }
  }

  tags = ["Enterprise", "SAML", "BOA-AMEX", each.value.name]
}

resource "azuread_service_principal" "saml_apps" {
  for_each = var.enable_entra_apps ? {
    for app in var.saml_applications : app.name => app
  } : {}

  client_id                    = azuread_application.saml_apps[each.key].client_id
  app_role_assignment_required = true
  preferred_single_sign_on_mode = "saml"

  saml_single_sign_on {
    relay_state = each.value.identifier_uri
  }

  tags = ["Enterprise", "SAML", "BOA-AMEX"]
}

# ═══════════════════════════════════════════════════════════
# API APPLICATION REGISTRATIONS — OAuth 2.0 client credentials
# Service-to-service authentication between microservices
# ═══════════════════════════════════════════════════════════

resource "azuread_application" "api_apps" {
  for_each = var.enable_entra_apps ? {
    for app in var.api_applications : app.name => app
  } : {}

  display_name = each.value.name
  description  = each.value.description

  identifier_uris = [each.value.api_identifier]

  api {
    # Define permissions (scopes) this API exposes
    # Other apps request these permissions
    dynamic "oauth2_permission_scope" {
      for_each = each.value.permissions
      content {
        id                         = uuidv5("dns", "${each.value.name}-${oauth2_permission_scope.value}")
        admin_consent_description  = "Allows access to ${oauth2_permission_scope.value}"
        admin_consent_display_name = oauth2_permission_scope.value
        enabled                    = true
        type                       = "Role"
        value                      = oauth2_permission_scope.value
      }
    }
  }

  # App roles for client credential flow
  dynamic "app_role" {
    for_each = each.value.permissions
    content {
      allowed_member_types = ["Application"]
      description          = "Allows ${app_role.value} on ${each.value.name}"
      display_name         = app_role.value
      enabled              = true
      id                   = uuidv5("dns", "${each.value.name}-role-${app_role.value}")
      value                = app_role.value
    }
  }

  tags = ["API", "OAuth2", "BOA-AMEX", each.value.name]
}

resource "azuread_service_principal" "api_apps" {
  for_each = var.enable_entra_apps ? {
    for app in var.api_applications : app.name => app
  } : {}

  client_id                    = azuread_application.api_apps[each.key].client_id
  app_role_assignment_required = false

  tags = ["API", "OAuth2", "BOA-AMEX"]
}

# ═══════════════════════════════════════════════════════════
# CLIENT SECRETS — for service-to-service authentication
# In production: stored in Secrets Manager with rotation
# ═══════════════════════════════════════════════════════════

resource "azuread_application_password" "api_secrets" {
  for_each = var.enable_entra_apps ? {
    for app in var.api_applications : app.name => app
  } : {}

  application_id = azuread_application.api_apps[each.key].id
  display_name   = "${each.value.name}-client-secret"

  end_date_relative = "8760h" # 1 year — rotated via Secrets Manager
}

# ═══════════════════════════════════════════════════════════
# GROUP ASSIGNMENTS — who can access which application
# Business unit groups assigned to enterprise applications
# ═══════════════════════════════════════════════════════════

# Note: In production, group assignments are done per
# application based on the assigned_groups variable.
# This creates the mapping:
#   BU-Card-Processing → LBB-CardAuth app
#   BU-Core-Banking → LBB-PaymentService, LBB-BankingPortal
#   BU-Executive → LBB-BI (read-only dashboards)
#   etc.

