# ============================================================
# LBBS Terraform — CloudWatch (Monitoring & Alerts)
# ============================================================
# Monitors the application and sends alerts when things go wrong.
# ============================================================

# ── Alarm: High CPU on backend ──
resource "aws_cloudwatch_metric_alarm" "backend_cpu_high" {
  alarm_name          = "${var.project_name}-backend-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300 # 5 minutes
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Backend CPU above 80% for 10 minutes"

  dimensions = {
    ClusterName = aws_ecs_cluster.lbbs.name
    ServiceName = aws_ecs_service.backend.name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

# ── Alarm: Database connections high ──
resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "${var.project_name}-rds-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 50
  alarm_description   = "RDS connections above 50"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.lbbs.id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

# ── SNS Topic for Alerts ──
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ── Dashboard ──
resource "aws_cloudwatch_dashboard" "lbbs" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Backend CPU Utilization"
          metrics = [["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.lbbs.name, "ServiceName", aws_ecs_service.backend.name]]
          period  = 300
          stat    = "Average"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Database Connections"
          metrics = [["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", aws_db_instance.lbbs.id]]
          period  = 300
          stat    = "Average"
        }
      },
    ]
  })
}
