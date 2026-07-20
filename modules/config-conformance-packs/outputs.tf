# ============================================================
# outputs.tf — Exported values from config-conformance-packs
# ============================================================

output "pci_dss_pack_id" {
  description = "PCI-DSS conformance pack ID"
  value       = var.deploy_conformance_packs ? aws_config_organization_conformance_pack.pci_dss[0].id : ""
}

output "nist_800_53_pack_id" {
  description = "NIST 800-53 conformance pack ID"
  value       = var.deploy_conformance_packs ? aws_config_organization_conformance_pack.nist_800_53[0].id : ""
}
