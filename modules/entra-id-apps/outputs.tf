output "saml_app_ids" {
  description = "SAML enterprise application IDs"
  value = var.enable_entra_apps ? {
    for name, app in azuread_application.saml_apps : name => app.client_id
  } : {}
}

output "api_app_ids" {
  description = "API application registration IDs"
  value = var.enable_entra_apps ? {
    for name, app in azuread_application.api_apps : name => app.client_id
  } : {}
}

output "group_ids" {
  description = "Business unit and role group IDs"
  value = var.enable_entra_apps ? merge(
    { for name, g in azuread_group.business_units : name => g.id },
    { for name, g in azuread_group.roles : name => g.id }
  ) : {}
}

output "sso_configuration_guide" {
  description = "SSO configuration guide for application teams"
  value = <<-EOT
    SSO Configuration for LBB Applications:
    
    SAML 2.0 (web applications):
      Identity Provider: Microsoft Entra ID
      Tenant: ${var.tenant_id}
      Login URL: https://login.microsoftonline.com/${var.tenant_id}/saml2
      Logout URL: https://login.microsoftonline.com/${var.tenant_id}/saml2
      Certificate: download from Entra ID > Enterprise Apps > SAML signing
      
    OAuth 2.0 (API authentication):
      Token endpoint: https://login.microsoftonline.com/${var.tenant_id}/oauth2/v2.0/token
      Authorization: https://login.microsoftonline.com/${var.tenant_id}/oauth2/v2.0/authorize
      JWKS URI: https://login.microsoftonline.com/${var.tenant_id}/discovery/v2.0/keys
      
    Application teams need:
      1. Client ID (from App Registration)
      2. Client Secret (stored in Secrets Manager)
      3. SAML metadata XML or OAuth endpoints above
      4. Group claim mapping for role-based access
  EOT
}

output "auth_architecture" {
  description = "Authentication architecture summary"
  value = {
    identity_provider    = "Microsoft Entra ID"
    tenant_id           = var.tenant_id
    saml_applications   = length(var.saml_applications)
    api_applications    = length(var.api_applications)
    business_unit_groups = length(var.business_unit_groups)
    role_groups         = length(var.role_groups)
    
    protocol_mapping = {
      web_sso              = "SAML 2.0 — browser-based SSO for human users"
      api_service_to_service = "OAuth 2.0 Client Credentials — machine-to-machine"
      api_user_delegated   = "OAuth 2.0 Authorization Code + PKCE — user-delegated API calls"
      token_format         = "JWT (RS256 signed by Entra ID)"
      token_validation     = "JWKS endpoint for public key retrieval"
    }
    
    conditional_access = {
      pci_apps     = "MFA required + compliant device + 15-min session timeout"
      standard_apps = "MFA required + 60-min session timeout"
      admin_access = "MFA required + compliant device + named location"
    }
  }
}

output "occ_evidence_note" {
  description = "OCC and PCI-DSS evidence from Entra ID SSO"
  value = "Satisfies: PCI-DSS Req 7 (restrict access by business need-to-know via group-based assignments), Req 8.1 (unique identification via Entra ID SSO), Req 8.2 (strong authentication via SAML 2.0 + MFA), Req 8.3 (MFA for all access via Conditional Access), Req 10.1 (audit trail via Entra ID sign-in logs). All application access flows through centralized Entra ID with SSO, eliminating local credentials and enabling immediate deprovisioning when employees depart."
}
