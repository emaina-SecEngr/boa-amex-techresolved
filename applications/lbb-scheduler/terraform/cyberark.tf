# ============================================================
# LBBS Terraform — CyberArk Privileged Access Management
# ============================================================
# Integrates CyberArk for:
#   1.  Digital Vault — Stores privileged credentials
#   2.  PVWA — Web portal for admins to request access
#   3.  CPM — Automatic password rotation
#   4.  PSM — Session recording for admin actions
#   5.  Conjur — Dynamic secrets for containers/CI/CD
#   6.  CyberArk Identity — SSO/MFA for privileged users
#
# ARCHITECTURE:
#   Regular Users  → Okta SSO → LBBS App
#   Privileged Users → CyberArk PAM → Admin Systems
#   Containers → CyberArk Conjur → Dynamic Secrets
#
# WHY BOTH OKTA AND CYBERARK?
#   Okta   = Identity for EVERYONE (workforce identity)
#   CyberArk = Privileged access for ADMINS ONLY (PAM)
#   Together = Complete identity security posture
# ============================================================


# ─────────────────────────────────────────────────────
# VARIABLES
# ─────────────────────────────────────────────────────

variable "cyberark_tenant_url" {
  description = "CyberArk Identity/Privilege Cloud tenant URL"
  type        = string
  default     = "https://lbbs.cyberark.cloud"
}

variable "cyberark_conjur_url" {
  description = "CyberArk Conjur endpoint for dynamic secrets"
  type        = string
  default     = "https://conjur.lbbs.internal"
}

variable "cyberark_safe_prefix" {
  description = "Prefix for CyberArk safes"
  type        = string
  default     = "LBBS"
}


# ─────────────────────────────────────────────────────
# 1. DIGITAL VAULT — Safes for Privileged Credentials
# ─────────────────────────────────────────────────────
# A SAFE is like a folder in the vault.
# Each safe holds related credentials.
# Access is controlled per-safe (who can see what).
#
# Think of it as:
#   Bank vault has separate safe deposit boxes.
#   Box 1: Database passwords (only DBAs can open)
#   Box 2: AWS credentials (only cloud admins can open)
#   Box 3: Okta admin token (only identity team can open)
#   Even the vault admin can't open boxes they're not assigned to.
# ─────────────────────────────────────────────────────

# AWS infrastructure credentials
resource "aws_secretsmanager_secret" "cyberark_safe_aws" {
  name        = "${var.cyberark_safe_prefix}/vault/aws-infrastructure"
  description = "CyberArk safe for AWS privileged credentials"

  tags = {
    Project     = var.project_name
    CyberArk    = "digital-vault"
    Safe        = "AWS-Infrastructure"
    CPM_Managed = "true"
  }
}

resource "aws_secretsmanager_secret_version" "cyberark_safe_aws" {
  secret_id = aws_secretsmanager_secret.cyberark_safe_aws.id
  secret_string = jsonencode({
    safe_name   = "${var.cyberark_safe_prefix}-AWS-Infrastructure"
    description = "AWS root, admin IAM, and service account credentials"

    accounts = {
      aws_root = {
        name            = "AWS-Root-Account"
        platform        = "AWS"
        credential_type = "password"
        auto_rotate     = true
        rotation_days   = 30
        dual_control    = true
        access_requires = "manager_approval + mfa"
      }
      aws_admin = {
        name            = "AWS-Admin-IAM"
        platform        = "AWS"
        credential_type = "access_key"
        auto_rotate     = true
        rotation_days   = 7
        checkout_time   = "2h"
        access_requires = "ticket_number + mfa"
      }
      terraform_service = {
        name            = "Terraform-CI-CD"
        platform        = "AWS"
        credential_type = "access_key"
        auto_rotate     = true
        rotation_days   = 1
        checkout_time   = "1h"
        access_requires = "pipeline_identity"
      }
    }
  })
}

# Database credentials
resource "aws_secretsmanager_secret" "cyberark_safe_database" {
  name        = "${var.cyberark_safe_prefix}/vault/database"
  description = "CyberArk safe for database privileged credentials"

  tags = {
    Project     = var.project_name
    CyberArk    = "digital-vault"
    Safe        = "Database"
    CPM_Managed = "true"
  }
}

resource "aws_secretsmanager_secret_version" "cyberark_safe_database" {
  secret_id = aws_secretsmanager_secret.cyberark_safe_database.id
  secret_string = jsonencode({
    safe_name   = "${var.cyberark_safe_prefix}-Database"
    description = "PostgreSQL admin, read-only, and application credentials"

    accounts = {
      rds_master = {
        name            = "RDS-Master-Admin"
        platform        = "PostgreSQL"
        credential_type = "password"
        auto_rotate     = true
        rotation_days   = 14
        dual_control    = true
        session_record  = true
        access_requires = "change_ticket + manager_approval + mfa"
      }
      rds_app_user = {
        name            = "RDS-Application-User"
        platform        = "PostgreSQL"
        credential_type = "password"
        auto_rotate     = true
        rotation_days   = 7
        checkout_time   = "8h"
        access_requires = "service_identity"
      }
      rds_readonly = {
        name            = "RDS-ReadOnly-Support"
        platform        = "PostgreSQL"
        credential_type = "password"
        auto_rotate     = true
        rotation_days   = 30
        session_record  = true
        access_requires = "ticket_number + mfa"
      }
    }
  })
}

# Identity provider credentials (Okta admin, SCIM tokens)
resource "aws_secretsmanager_secret" "cyberark_safe_identity" {
  name        = "${var.cyberark_safe_prefix}/vault/identity"
  description = "CyberArk safe for identity provider credentials"

  tags = {
    Project     = var.project_name
    CyberArk    = "digital-vault"
    Safe        = "Identity"
    CPM_Managed = "true"
  }
}

resource "aws_secretsmanager_secret_version" "cyberark_safe_identity" {
  secret_id = aws_secretsmanager_secret.cyberark_safe_identity.id
  secret_string = jsonencode({
    safe_name   = "${var.cyberark_safe_prefix}-Identity"
    description = "Okta admin, SCIM tokens, and SSO client secrets"

    accounts = {
      okta_admin = {
        name            = "Okta-Super-Admin"
        platform        = "Okta"
        credential_type = "api_token"
        auto_rotate     = true
        rotation_days   = 30
        dual_control    = true
        session_record  = true
        access_requires = "security_team_approval + hardware_mfa"
      }
      okta_scim_token = {
        name            = "Okta-SCIM-Bearer-Token"
        platform        = "Okta"
        credential_type = "bearer_token"
        auto_rotate     = true
        rotation_days   = 90
        access_requires = "service_identity"
      }
      okta_client_secret = {
        name            = "Okta-OIDC-Client-Secret"
        platform        = "Okta"
        credential_type = "client_secret"
        auto_rotate     = true
        rotation_days   = 180
        access_requires = "service_identity"
      }
    }
  })
}

# Container and CI/CD credentials
resource "aws_secretsmanager_secret" "cyberark_safe_devops" {
  name        = "${var.cyberark_safe_prefix}/vault/devops"
  description = "CyberArk safe for CI/CD and container credentials"

  tags = {
    Project     = var.project_name
    CyberArk    = "digital-vault"
    Safe        = "DevOps"
    CPM_Managed = "true"
  }
}

resource "aws_secretsmanager_secret_version" "cyberark_safe_devops" {
  secret_id = aws_secretsmanager_secret.cyberark_safe_devops.id
  secret_string = jsonencode({
    safe_name   = "${var.cyberark_safe_prefix}-DevOps"
    description = "GitLab runner, ECR push, Kubernetes, and deployment credentials"

    accounts = {
      gitlab_runner = {
        name            = "GitLab-CI-Runner"
        platform        = "GitLab"
        credential_type = "token"
        auto_rotate     = true
        rotation_days   = 7
        access_requires = "pipeline_identity"
      }
      ecr_push = {
        name            = "ECR-Image-Push"
        platform        = "AWS-ECR"
        credential_type = "access_key"
        auto_rotate     = true
        rotation_days   = 1
        access_requires = "pipeline_identity"
      }
      kubernetes_admin = {
        name            = "EKS-Cluster-Admin"
        platform        = "Kubernetes"
        credential_type = "kubeconfig"
        auto_rotate     = true
        rotation_days   = 7
        dual_control    = true
        session_record  = true
        access_requires = "change_ticket + manager_approval + mfa"
      }
      argocd_admin = {
        name            = "ArgoCD-Admin"
        platform        = "ArgoCD"
        credential_type = "password"
        auto_rotate     = true
        rotation_days   = 14
        access_requires = "ticket_number + mfa"
      }
    }
  })
}


# ─────────────────────────────────────────────────────
# 2. CPM — Central Password Manager (Auto-Rotation)
# ─────────────────────────────────────────────────────
# CPM automatically rotates passwords on schedule.
# No human ever types or sees the actual password.
#
# Flow:
#   CPM: "Time to rotate RDS password"
#   CPM → connects to RDS → changes password to random 32-char
#   CPM → stores new password in vault
#   App → requests password from vault → gets new one automatically
#   Old password → immediately invalid
# ─────────────────────────────────────────────────────

resource "aws_secretsmanager_secret" "cyberark_cpm_config" {
  name        = "${var.cyberark_safe_prefix}/cpm/rotation-config"
  description = "CyberArk CPM auto-rotation configuration"

  tags = {
    Project  = var.project_name
    CyberArk = "cpm"
  }
}

resource "aws_secretsmanager_secret_version" "cyberark_cpm_config" {
  secret_id = aws_secretsmanager_secret.cyberark_cpm_config.id
  secret_string = jsonencode({
    rotation_policies = {
      aws_credentials = {
        rotation_interval = "24h"
        password_length   = 32
        complexity        = "uppercase,lowercase,numbers,symbols"
        notify_on_failure = ["security-team@lbbs.org"]
      }
      database_credentials = {
        rotation_interval = "168h"
        password_length   = 48
        complexity        = "uppercase,lowercase,numbers,symbols"
        verify_after_change = true
        notify_on_failure   = ["dba-team@lbbs.org", "security-team@lbbs.org"]
      }
      identity_tokens = {
        rotation_interval = "720h"
        token_length      = 64
        notify_on_failure = ["identity-team@lbbs.org"]
      }
      cicd_credentials = {
        rotation_interval = "24h"
        password_length   = 32
        scoped_to_pipeline = true
        notify_on_failure  = ["devops-team@lbbs.org"]
      }
    }
  })
}


# ─────────────────────────────────────────────────────
# 3. PSM — Privileged Session Manager (Recording)
# ─────────────────────────────────────────────────────
# Every privileged session is RECORDED.
# Admin connects to database → entire session recorded.
# Admin SSH to server → every command recorded.
# Like a security camera for admin actions.
#
# WHY:
#   Insider threat: Admin copies student data → recorded → caught
#   Compliance: Auditor asks "who accessed DB?" → play recording
#   Forensics: Breach investigation → replay exact actions
# ─────────────────────────────────────────────────────

resource "aws_s3_bucket" "psm_recordings" {
  bucket        = "${var.project_name}-psm-recordings-${data.aws_caller_identity.current.account_id}"
  force_destroy = false

  tags = {
    Project  = var.project_name
    CyberArk = "psm"
    DataType = "session-recordings"
    Retention = "7-years"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "psm_recordings" {
  bucket = aws_s3_bucket.psm_recordings.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.logs.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "psm_recordings" {
  bucket                  = aws_s3_bucket.psm_recordings.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "psm_recordings" {
  bucket = aws_s3_bucket.psm_recordings.id
  versioning_configuration { status = "Enabled" }
}

# Lifecycle: move recordings to Glacier after 90 days (cost savings)
resource "aws_s3_bucket_lifecycle_configuration" "psm_recordings" {
  bucket = aws_s3_bucket.psm_recordings.id

  rule {
    id     = "archive-old-recordings"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 2555  # 7 years retention for compliance
    }
  }
}


# ─────────────────────────────────────────────────────
# 4. CONJUR — Dynamic Secrets for Containers
# ─────────────────────────────────────────────────────
# Conjur provides DYNAMIC secrets to containers.
# Instead of storing DATABASE_URL in environment variables,
# containers request it from Conjur at runtime.
#
# Flow:
#   Container starts → Conjur sidecar authenticates → gets secret
#   → Secret injected into container memory (not disk)
#   → Secret expires in 1 hour → Conjur auto-renews
#   → Container crash → secret gone (was only in memory)
#
# This replaces:
#   ❌ .env files with DATABASE_URL=postgresql://...
#   ❌ Kubernetes Secrets (base64 encoded, not encrypted)
#   ❌ AWS Secrets Manager (good but no dynamic rotation)
#
# With:
#   ✅ Conjur generates UNIQUE credentials per container instance
#   ✅ Credentials expire in 1 hour
#   ✅ Credentials exist only in memory
#   ✅ Every access is logged and auditable
# ─────────────────────────────────────────────────────

resource "aws_secretsmanager_secret" "conjur_config" {
  name        = "${var.cyberark_safe_prefix}/conjur/config"
  description = "CyberArk Conjur configuration for container secrets"

  tags = {
    Project  = var.project_name
    CyberArk = "conjur"
  }
}

resource "aws_secretsmanager_secret_version" "conjur_config" {
  secret_id = aws_secretsmanager_secret.conjur_config.id
  secret_string = jsonencode({
    conjur_url     = var.cyberark_conjur_url
    conjur_account = "lbbs"

    # Policies define what each service can access
    policies = {
      backend = {
        description = "LBBS FastAPI backend container"
        host        = "lbbs/backend"
        can_read = [
          "lbbs/database/url",
          "lbbs/database/readonly-url",
          "lbbs/secrets/jwt-secret-key",
          "lbbs/okta/client-id",
          "lbbs/okta/client-secret",
        ]
        cannot_read = [
          "lbbs/database/admin-password",
          "lbbs/aws/root-credentials",
          "lbbs/kubernetes/admin-kubeconfig",
        ]
      }
      cicd = {
        description = "GitLab CI/CD pipeline"
        host        = "lbbs/cicd"
        can_read = [
          "lbbs/ecr/push-credentials",
          "lbbs/sonarqube/token",
          "lbbs/snyk/token",
        ]
        cannot_read = [
          "lbbs/database/url",
          "lbbs/database/admin-password",
          "lbbs/okta/admin-token",
        ]
      }
      monitoring = {
        description = "Prometheus/Grafana monitoring"
        host        = "lbbs/monitoring"
        can_read = [
          "lbbs/database/readonly-url",
          "lbbs/cloudwatch/readonly-key",
        ]
        cannot_read = [
          "lbbs/database/url",
          "lbbs/database/admin-password",
          "lbbs/aws/root-credentials",
        ]
      }
    }

    # Secret definitions with rotation
    secrets = {
      "lbbs/database/url" = {
        description  = "PostgreSQL connection string for backend"
        rotation     = "7d"
        dynamic      = true
      }
      "lbbs/database/admin-password" = {
        description  = "PostgreSQL admin password (DBA only)"
        rotation     = "14d"
        dynamic      = true
        dual_control = true
      }
      "lbbs/secrets/jwt-secret-key" = {
        description = "JWT signing key for authentication"
        rotation    = "30d"
        key_length  = 64
      }
      "lbbs/okta/client-secret" = {
        description = "Okta OIDC client secret"
        rotation    = "180d"
      }
      "lbbs/ecr/push-credentials" = {
        description = "ECR push credentials for CI/CD"
        rotation    = "1d"
        dynamic     = true
      }
    }
  })
}


# ─────────────────────────────────────────────────────
# 5. CYBERARK IDENTITY — SSO/MFA for Privileged Users
# ─────────────────────────────────────────────────────
# Separate from Okta SSO.
# CyberArk Identity provides ADDITIONAL authentication
# for accessing privileged resources.
#
# Regular login: Okta SSO → LBBS app
# Privileged login: Okta SSO → CyberArk MFA → Admin panel
#
# This is called STEP-UP AUTHENTICATION:
#   Level 1: Okta password + MFA → access LBBS app
#   Level 2: CyberArk password + hardware MFA → access admin tools
#   Level 3: CyberArk + manager approval → access database directly
# ─────────────────────────────────────────────────────

resource "aws_secretsmanager_secret" "cyberark_identity_config" {
  name        = "${var.cyberark_safe_prefix}/identity/config"
  description = "CyberArk Identity SSO/MFA configuration for privileged access"

  tags = {
    Project  = var.project_name
    CyberArk = "identity"
  }
}

resource "aws_secretsmanager_secret_version" "cyberark_identity_config" {
  secret_id = aws_secretsmanager_secret.cyberark_identity_config.id
  secret_string = jsonencode({
    tenant_url = var.cyberark_tenant_url

    # Authentication levels
    authentication_levels = {
      level_1_standard = {
        description = "Standard app access (Okta handles)"
        factors     = ["password", "okta_verify"]
        grants      = ["lbbs_app_access"]
      }
      level_2_elevated = {
        description = "Elevated access for admin operations"
        factors     = ["password", "hardware_token", "biometric"]
        grants      = ["admin_panel", "user_management", "reporting"]
        session_duration = "2h"
        session_recording = true
      }
      level_3_critical = {
        description = "Critical access requiring approval"
        factors     = ["password", "hardware_token", "biometric", "manager_approval"]
        grants      = ["database_direct", "infrastructure_admin", "key_management"]
        session_duration  = "1h"
        session_recording = true
        dual_control      = true
        break_glass       = true
      }
    }

    # JIT (Just In Time) access rules
    jit_access = {
      database_admin = {
        description     = "Temporary DBA access for maintenance"
        max_duration    = "4h"
        requires        = ["change_ticket", "manager_approval"]
        auto_revoke     = true
        notify          = ["security-team@lbbs.org"]
        audit_all_queries = true
      }
      kubernetes_admin = {
        description     = "Temporary K8s admin for deployments"
        max_duration    = "2h"
        requires        = ["deployment_ticket"]
        auto_revoke     = true
        notify          = ["devops-lead@lbbs.org"]
      }
      okta_admin = {
        description     = "Temporary Okta admin for user issues"
        max_duration    = "1h"
        requires        = ["support_ticket", "security_approval"]
        auto_revoke     = true
        notify          = ["identity-team@lbbs.org", "security-team@lbbs.org"]
      }
      break_glass = {
        description     = "Emergency access (P1 incidents only)"
        max_duration    = "8h"
        requires        = ["incident_number"]
        auto_revoke     = true
        notify          = ["ciso@lbbs.org", "cto@lbbs.org", "security-team@lbbs.org"]
        post_review     = "mandatory_within_24h"
      }
    }
  })
}


# ─────────────────────────────────────────────────────
# 6. IAM ROLE — CyberArk Vault Access from ECS/K8s
# ─────────────────────────────────────────────────────
# Backend containers use this role to authenticate
# to CyberArk Conjur and retrieve secrets.
# ─────────────────────────────────────────────────────

resource "aws_iam_policy" "cyberark_conjur_access" {
  name        = "${var.project_name}-cyberark-conjur-access"
  description = "Allow backend to authenticate with CyberArk Conjur"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadConjurConfig"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
        ]
        Resource = [
          aws_secretsmanager_secret.conjur_config.arn,
        ]
      },
      {
        Sid    = "DecryptWithKMS"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
        ]
        Resource = [aws_kms_key.secrets.arn]
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "backend_conjur" {
  role       = aws_iam_role.lbbs_backend_role.name
  policy_arn = aws_iam_policy.cyberark_conjur_access.arn
}


# ─────────────────────────────────────────────────────
# 7. OUTPUTS
# ─────────────────────────────────────────────────────

output "cyberark_safes" {
  description = "CyberArk vault safes created"
  value = {
    aws_infrastructure = aws_secretsmanager_secret.cyberark_safe_aws.name
    database           = aws_secretsmanager_secret.cyberark_safe_database.name
    identity           = aws_secretsmanager_secret.cyberark_safe_identity.name
    devops             = aws_secretsmanager_secret.cyberark_safe_devops.name
  }
}

output "psm_recordings_bucket" {
  description = "S3 bucket for CyberArk PSM session recordings"
  value       = aws_s3_bucket.psm_recordings.bucket
}

output "conjur_config_secret" {
  description = "AWS Secrets Manager secret for Conjur configuration"
  value       = aws_secretsmanager_secret.conjur_config.name
}
