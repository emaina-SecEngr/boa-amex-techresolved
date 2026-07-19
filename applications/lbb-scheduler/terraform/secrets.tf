# ============================================================
# LBBS Terraform — Secrets Manager
# ============================================================
# Stores secrets securely. Replaces .env file in production.
# Backend reads these at startup via IAM role.
# ============================================================

resource "aws_secretsmanager_secret" "jwt_secret" {
  name        = "${var.project_name}/SECRET_KEY"
  description = "JWT signing key for LBBS backend"
  tags        = { Name = "${var.project_name}-jwt-secret" }
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = var.jwt_secret_key  # From terraform.tfvars
}

resource "aws_secretsmanager_secret" "database_url" {
  name        = "${var.project_name}/DATABASE_URL"
  description = "PostgreSQL connection string for LBBS"
  tags        = { Name = "${var.project_name}-database-url" }
}

resource "aws_secretsmanager_secret_version" "database_url" {
  secret_id = aws_secretsmanager_secret.database_url.id
  secret_string = "postgresql://${aws_db_instance.lbbs.username}:${var.db_password}@${aws_db_instance.lbbs.endpoint}/${aws_db_instance.lbbs.db_name}"
}

# ── Auto-rotation for JWT secret (every 90 days) ──
# resource "aws_secretsmanager_secret_rotation" "jwt_rotation" {
#   secret_id           = aws_secretsmanager_secret.jwt_secret.id
#   rotation_lambda_arn = aws_lambda_function.secret_rotator.arn
#   rotation_rules { automatically_after_days = 90 }
# }
