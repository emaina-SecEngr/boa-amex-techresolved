# ============================================================
# outputs.tf — Exported values from detective module
# ============================================================

output "graph_arn" {
  description = "Detective behavior graph ARN"
  value       = aws_detective_graph.main.graph_arn
}

output "detective_status" {
  description = "Detective configuration summary"
  value = {
    graph_arn       = aws_detective_graph.main.graph_arn
    member_accounts = var.member_accounts
    org_datasources = var.enable_org_datasources ? "ENABLED" : "DISABLED"
  }
}

output "verify_graph_command" {
  description = "Verify Detective graph is active"
  value       = "aws detective list-graphs --query 'GraphList[].{Arn:Arn,CreatedTime:CreatedTime}' --output table --profile security-tooling"
}

output "verify_members_command" {
  description = "Verify member accounts in Detective graph"
  value       = "aws detective list-members --graph-arn ${aws_detective_graph.main.graph_arn} --query 'MemberDetails[].{AccountId:AccountId,Status:Status}' --output table --profile security-tooling"
}

output "occ_evidence_note" {
  description = "OCC examination evidence this module provides"
  value       = "Satisfies: OCC incident investigation requirement, PCI-DSS Req 12.10 (incident response plan). Detective provides automated forensic timeline and blast radius assessment — reduces investigation time from days to minutes."
}

output "import_command" {
  description = "Terraform import command for existing graph"
  value       = "terraform import module.detective.aws_detective_graph.main ${var.existing_graph_arn}"
}