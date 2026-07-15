# ============================================================
# outputs.tf — Exported values from palo-alto module
# ============================================================

output "security_vpc_id" {
  description = "Security VPC ID — hosts firewall inspection infrastructure"
  value       = var.enable_palo_alto || var.enable_aws_network_firewall ? aws_vpc.security[0].id : ""
}

output "security_vpc_cidr" {
  description = "Security VPC CIDR block"
  value       = var.security_vpc_cidr
}

output "transit_gateway_id" {
  description = "Transit Gateway ID — connect workload VPCs here for hub-and-spoke"
  value       = var.enable_transit_gateway ? aws_ec2_transit_gateway.main[0].id : ""
}

output "transit_gateway_arn" {
  description = "Transit Gateway ARN"
  value       = var.enable_transit_gateway ? aws_ec2_transit_gateway.main[0].arn : ""
}

output "network_firewall_arn" {
  description = "AWS Network Firewall ARN"
  value       = var.enable_aws_network_firewall ? aws_networkfirewall_firewall.main[0].arn : ""
}

output "gwlb_endpoint_service_name" {
  description = "GWLB VPC Endpoint Service name — workload VPCs create endpoints to this service for Palo Alto inspection"
  value       = var.enable_palo_alto ? aws_vpc_endpoint_service.gwlb[0].service_name : ""
}

output "palo_alto_instance_ids" {
  description = "Palo Alto EC2 instance IDs"
  value       = var.enable_palo_alto ? aws_instance.palo_alto[*].id : []
}

output "inspection_subnet_ids" {
  description = "Inspection subnet IDs — firewall endpoints deployed here"
  value       = var.enable_palo_alto || var.enable_aws_network_firewall ? aws_subnet.inspection[*].id : []
}

output "firewall_alerts_topic_arn" {
  description = "SNS topic ARN for firewall threat alerts"
  value       = var.enable_palo_alto || var.enable_aws_network_firewall ? aws_sns_topic.firewall_alerts[0].arn : ""
}

output "network_status" {
  description = "Network security configuration summary"
  value = {
    security_vpc         = var.enable_palo_alto || var.enable_aws_network_firewall ? "ENABLED — ${var.security_vpc_cidr}" : "DISABLED"
    transit_gateway      = var.enable_transit_gateway ? "ENABLED" : "DISABLED — toggle enable_transit_gateway=true"
    palo_alto            = var.enable_palo_alto ? "ENABLED — ${var.palo_alto_instance_count} instances" : "DISABLED — toggle enable_palo_alto=true"
    aws_network_firewall = var.enable_aws_network_firewall ? "ENABLED — Suricata IDS/IPS" : "DISABLED — toggle enable_aws_network_firewall=true"
    ssl_decryption       = var.enable_palo_alto ? "ENABLED via Palo Alto" : "NOT AVAILABLE — requires Palo Alto"
    app_id               = var.enable_palo_alto ? "ENABLED via Palo Alto" : "NOT AVAILABLE — requires Palo Alto"
    sentinel_integration = var.enable_sentinel_integration ? "ENABLED" : "DISABLED — pending Azure subscription"
  }
}

output "activation_instructions" {
  description = "How to activate network security components"
  value       = <<-EOT
    To activate AWS Network Firewall (sandbox - $285/month):
      Set enable_aws_network_firewall = true
      Set enable_transit_gateway = true
      Run: terraform apply

    To activate Palo Alto VM-Series (production - $1,440+/month):
      1. Subscribe to Palo Alto VM-Series on AWS Marketplace
      2. Get AMI ID for us-east-1
      3. Set palo_alto_ami_id = "ami-XXXXXXXXX"
      4. Set enable_palo_alto = true
      5. Set enable_transit_gateway = true
      6. Run: terraform apply
      7. Configure via Panorama or direct management

    To connect workload VPCs (after firewall is active):
      Each workload VPC needs:
        - TGW attachment
        - Route table pointing 0.0.0.0/0 to TGW
        - GWLB VPC endpoint (for Palo Alto)
      These are added in modules/network-perimeter/
  EOT
}

output "occ_evidence_note" {
  description = "OCC examination evidence this module provides"
  value       = "Satisfies: OCC network security requirement, PCI-DSS Req 1.1 (firewall configuration standards), PCI-DSS Req 1.2 (restrict connections between untrusted networks), PCI-DSS Req 1.3 (restrict inbound/outbound traffic to CDE). Network Firewall/Palo Alto provides continuous inspection of all inter-VPC and internet traffic with complete audit logs."
}