# ============================================================
# main.tf — Organization-wide AWS Config conformance packs
# Module: config-conformance-packs
#
# WHAT THIS FILE DOES:
# Defines org-wide Config conformance packs mapping AWS-managed
# rule sets to compliance frameworks. Deployed from the Config
# delegated administrator account (Security Tooling), which is
# why this module uses the plain default provider rather than
# a cross-account alias — same pattern as
# aws_securityhub_organization_configuration in modules/security-hub.
#
# PREREQUISITE: aws_organizations_delegated_administrator.config
# (modules/aws-organization) must already be active, delegating
# config.amazonaws.com to this account. It is.
#
# KNOWN GAPS:
#   - No AWS-managed conformance pack maps to OCC 12 CFR 30.
#     PCI-DSS and NIST 800-53 packs are the closest available
#     coverage; OCC-specific controls remain a manual/GRC-tool
#     responsibility.
#   - Definition only. AWS Config is not yet recording in any
#     account (that rollout is a separate, later phase), so
#     these packs will show no evaluations until per-account
#     Config recording is enabled.
# ============================================================

resource "aws_config_organization_conformance_pack" "pci_dss" {
  count = var.deploy_conformance_packs ? 1 : 0

  name              = "${var.project_prefix}-pci-dss"
  template_s3_uri   = "s3://awsconfigconformancepacks/Operational-Best-Practices-for-PCI-DSS.yaml"
  excluded_accounts = var.excluded_accounts
}

resource "aws_config_organization_conformance_pack" "nist_800_53" {
  count = var.deploy_conformance_packs ? 1 : 0

  name              = "${var.project_prefix}-nist-800-53"
  template_s3_uri   = "s3://awsconfigconformancepacks/Operational-Best-Practices-for-NIST-800-53.yaml"
  excluded_accounts = var.excluded_accounts
}
