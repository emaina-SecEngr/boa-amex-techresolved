# ============================================================
# LBBS Terraform — ALB (Application Load Balancer)
# ============================================================
# Routes internet traffic to our containers.
#
# FLOW:
#   User → HTTPS → ALB → picks a healthy container → response
#   ALB checks container health every 30 seconds.
#   Unhealthy container? ALB stops sending traffic to it.
# ============================================================

resource "aws_lb" "lbbs" {
  name               = "${var.project_name}-alb"
  internal           = false # Internet-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = { Name = "${var.project_name}-alb" }
}

# ── Target Group (where ALB sends traffic) ──
resource "aws_lb_target_group" "backend" {
  name        = "${var.project_name}-backend-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.lbbs.id
  target_type = "ip" # ECS Fargate uses IP targets

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }
}

# ── HTTPS Listener (port 443) ──
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.lbbs.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.lbbs.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

# ── HTTP Listener (redirect to HTTPS) ──
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.lbbs.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
