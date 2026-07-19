# ============================================================
# LBBS Terraform — ECS (Elastic Container Service)
# ============================================================
# Runs our Docker containers in AWS.
#
# WHAT IS ECS FARGATE?
#   Serverless containers — you don't manage any servers.
#   Just tell AWS: "Run this Docker image with this much CPU/RAM"
#   AWS handles everything else.
#
# ARCHITECTURE:
#   ECS Cluster → contains Services → contains Tasks (containers)
#
#   Cluster: lbbs-production
#   ├── Service: lbbs-backend (3 tasks)
#   │   ├── Task 1: FastAPI container (10.0.10.5:8000)
#   │   ├── Task 2: FastAPI container (10.0.10.6:8000)
#   │   └── Task 3: FastAPI container (10.0.11.5:8000)
#   └── Service: lbbs-frontend (2 tasks)
#       ├── Task 1: React container (10.0.10.7:5173)
#       └── Task 2: React container (10.0.11.7:5173)
# ============================================================

# ── ECS Cluster ──
resource "aws_ecs_cluster" "lbbs" {
  name = "${var.project_name}-production"

  setting {
    name  = "containerInsights"
    value = "enabled" # Detailed monitoring
  }

  tags = { Name = "${var.project_name}-cluster" }
}

# ── CloudWatch Log Groups ──
resource "aws_cloudwatch_log_group" "backend" {
  name              = "/lbbs/backend"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/lbbs/frontend"
  retention_in_days = 30
}

# ── Backend Task Definition ──
resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.project_name}-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256" # 0.25 vCPU
  memory                   = "512" # 512 MB RAM
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.lbbs_backend_role.arn

  container_definitions = jsonencode([
    {
      name  = "lbbs-backend"
      image = "${aws_ecr_repository.backend.repository_url}:latest"
      portMappings = [{
        containerPort = 8000
        protocol      = "tcp"
      }]
      environment = [
        { name = "APP_ENV", value = "production" },
        { name = "DEBUG", value = "false" },
      ]
      secrets = [
        {
          name      = "SECRET_KEY"
          valueFrom = aws_secretsmanager_secret.jwt_secret.arn
        },
        {
          name      = "DATABASE_URL"
          valueFrom = aws_secretsmanager_secret.database_url.arn
        },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.backend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "backend"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8000/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])
}

# ── Backend Service ──
resource "aws_ecs_service" "backend" {
  name            = "${var.project_name}-backend"
  cluster         = aws_ecs_cluster.lbbs.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 2 # Run 2 copies for high availability
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_groups  = [aws_security_group.backend.id]
    assign_public_ip = false # Private subnet — no public IP
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "lbbs-backend"
    container_port   = 8000
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true # Auto-rollback if deployment fails
  }

  depends_on = [aws_lb_listener.https]
}

# ── Auto-Scaling ──
resource "aws_appautoscaling_target" "backend" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.lbbs.name}/${aws_ecs_service.backend.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "backend_cpu" {
  name               = "${var.project_name}-backend-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.backend.resource_id
  scalable_dimension = aws_appautoscaling_target.backend.scalable_dimension
  service_namespace  = aws_appautoscaling_target.backend.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0 # Scale up when CPU > 70%
  }
}
