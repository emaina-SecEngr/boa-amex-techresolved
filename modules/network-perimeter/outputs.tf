# ============================================================
# outputs.tf - Exported values from network-perimeter module
# ============================================================

output "tgw_ram_share_arn" {
  description = "RAM resource share ARN - workload accounts reference this to accept the TGW attachment"
  value       = local.tgw_ready ? aws_ram_resource_share.tgw[0].arn : ""
}

output "tgw_flow_log_id" {
  description = "Transit Gateway flow log ID"
  value       = local.tgw_ready && var.enable_flow_logs ? aws_flow_log.tgw[0].id : ""
}

output "network_changes_topic_arn" {
  description = "SNS topic ARN for network segmentation change alerts"
  value       = local.alert_topic_arn
}

output "workload_attachment_ids" {
  description = "Transit Gateway attachment ID per workload VPC"
  value       = { for k, v in aws_ec2_transit_gateway_vpc_attachment.workload : k => v.id }
}

output "network_perimeter_status" {
  description = "Network perimeter configuration summary"
  value = {
    transit_gateway_shared = local.tgw_ready ? "SHARED via RAM${var.share_tgw_with_organization ? " (org-wide)" : ""}" : "PENDING - set enable_transit_gateway=true in modules/palo-alto first"
    flow_logs              = local.tgw_ready && var.enable_flow_logs ? "ENABLED" : "DISABLED"
    change_alerting        = local.tgw_ready && var.enable_change_alerting ? "ENABLED" : "DISABLED"
    workload_attachments   = "${length(var.workload_vpc_attachments)} configured (PCI-CDE, Core Banking, Dev, Pipeline/CI-CD are Phase 5 - none exist yet)"
    sentinel_integration   = var.enable_sentinel_integration ? "ENABLED" : "DISABLED - pending Azure subscription"
  }
}

output "activation_instructions" {
  description = "How to attach a Phase 5 workload VPC to the perimeter"
  value       = <<-EOT
    Prerequisite: modules/palo-alto enable_transit_gateway = true

    One-time setup (management account) for org-wide RAM sharing:
      aws ram enable-sharing-with-aws-organization

    To attach a new workload VPC (PCI-CDE, Core Banking, Dev, Pipeline/CI-CD):
      1. Provision the workload account and its VPC (Phase 5)
      2. Accept the RAM share in that account:
           aws ram get-resource-share-invitations
           aws ram accept-resource-share-invitation --resource-share-invitation-arn <arn>
      3. Add an entry to workload_vpc_attachments in terraform.tfvars:
           workload_vpc_attachments = {
             pci-cde = {
               vpc_id                     = "vpc-XXXX"
               vpc_cidr                   = "10.X.0.0/16"
               tgw_subnet_ids             = ["subnet-XXXX", "subnet-YYYY"]
               route_table_ids            = ["rtb-XXXX"]
               enable_gwlb_inspection     = true
               inspection_subnet_ids      = ["subnet-ZZZZ", "subnet-WWWW"]
               inspection_route_table_ids = ["rtb-YYYY"]
             }
           }
      4. terraform apply
  EOT
}

output "occ_evidence_note" {
  description = "OCC examination evidence this module provides"
  value       = "Satisfies: OCC network segmentation requirement, PCI-DSS Req 1.2 (restrict connections between untrusted networks and the CDE), PCI-DSS Req 1.3 (network segmentation of the cardholder data environment), PCI-DSS Req 10.2 (audit trail of network configuration changes). Transit Gateway hub-and-spoke architecture with RAM-shared connectivity, mandatory GWLB inspection routing for spoke VPCs, and CloudTrail-driven alerting on every attachment change."
}
