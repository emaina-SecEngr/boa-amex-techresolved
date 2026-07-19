# ============================================================
# LBBS Terraform — Outputs
# ============================================================

output "backend_role_arn" {
  description = "ARN of the backend service IAM role"
  value       = aws_iam_role.lbbs_backend_role.arn
}

output "ecs_execution_role_arn" {
  description = "ARN of the ECS execution role"
  value       = aws_iam_role.ecs_execution_role.arn
}

output "cicd_role_arn" {
  description = "ARN of the CI/CD deployment role"
  value       = aws_iam_role.cicd_deployment_role.arn
}

output "admin_group_name" {
  description = "Name of the admin IAM group"
  value       = aws_iam_group.lbbs_admins.name
}

output "developer_group_name" {
  description = "Name of the developer IAM group"
  value       = aws_iam_group.lbbs_developers.name
}

output "district_groups" {
  description = "Map of district IAM groups created"
  value       = { for k, v in aws_iam_group.district_groups : k => v.name }
}

output "admin_users_created" {
  description = "List of IAM users created"
  value       = [for u in aws_iam_user.admin_users : u.name]
}

output "password_policy" {
  description = "Password policy configuration"
  value = {
    min_length       = aws_iam_account_password_policy.strict.minimum_password_length
    max_age_days     = aws_iam_account_password_policy.strict.max_password_age
    reuse_prevention = aws_iam_account_password_policy.strict.password_reuse_prevention
  }
}
