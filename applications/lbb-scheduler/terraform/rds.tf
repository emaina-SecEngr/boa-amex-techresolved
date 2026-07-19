# ============================================================
# LBBS Terraform — RDS (PostgreSQL Database)
# ============================================================
# Creates a managed PostgreSQL database to replace SQLite.
#
# WHAT IS RDS?
#   AWS manages the database server for you:
#     ✅ Automatic backups (daily)
#     ✅ Automatic patching (security updates)
#     ✅ Encryption at rest (data encrypted on disk)
#     ✅ Multi-AZ failover (optional — auto-switch if server dies)
#     ✅ Point-in-time recovery (restore to any second in last 7 days)
#
# UNDER THE HOOD:
#   POST rds:CreateDBInstance → AWS provisions a PostgreSQL server
#   AWS assigns it a DNS endpoint:
#     lbbs-production.abc123.us-west-2.rds.amazonaws.com
#   Our backend connects to this endpoint instead of SQLite file
# ============================================================

resource "aws_db_subnet_group" "lbbs" {
  name = "${var.project_name}-db-subnet-group"
  subnet_ids = [
    aws_subnet.data_a.id,
    aws_subnet.data_b.id,
  ]
  description = "Database subnets for LBBS"
  tags        = { Name = "${var.project_name}-db-subnet-group" }
}

resource "aws_db_instance" "lbbs" {
  identifier            = "${var.project_name}-production"
  engine                = "postgres"
  engine_version        = "15"
  instance_class        = "db.t3.micro" # Free tier eligible
  allocated_storage     = 20            # 20 GB storage
  max_allocated_storage = 100           # Auto-scale up to 100 GB

  db_name  = "lbbs_production"
  username = "lbbs_admin"
  password = var.db_password # From terraform.tfvars (never in Git)

  # Network
  db_subnet_group_name   = aws_db_subnet_group.lbbs.name
  vpc_security_group_ids = [aws_security_group.database.id]
  publicly_accessible    = false # CRITICAL: database NOT on internet

  # Backups
  backup_retention_period = 7             # Keep 7 days of backups
  backup_window           = "03:00-04:00" # Backup at 3 AM UTC
  maintenance_window      = "sun:04:00-sun:05:00"

  # Encryption
  storage_encrypted = true # Encrypt data at rest

  # Deletion protection
  deletion_protection       = true # Can't accidentally delete
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-final-snapshot"

  tags = { Name = "${var.project_name}-postgres" }
}
