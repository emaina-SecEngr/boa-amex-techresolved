# ============================================================
# LBBS Terraform — ACM (SSL Certificate)
# ============================================================
# Creates a FREE SSL certificate for HTTPS.
# ============================================================

resource "aws_acm_certificate" "lbbs" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${var.domain_name}",  # Wildcard: api.lbbs.org, www.lbbs.org, etc.
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.project_name}-ssl-cert" }
}