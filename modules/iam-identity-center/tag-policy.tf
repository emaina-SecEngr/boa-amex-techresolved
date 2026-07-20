# ============================================================
# tag-policy.tf — Tag governance
# Module: iam-identity-center
#
# WHAT THIS FILE DOES:
# Two independent controls, kept on separate toggles because
# they carry very different risk:
#   1. Organizations Tag Policy — ADVISORY. Standardizes allowed
#      values for key tags and surfaces non-compliant resources
#      in Resource Groups Tag Editor / AWS Config compliance
#      reports. Does not block anything.
#   2. DenyUntaggedResourceCreation SCP — ENFORCING. Actually
#      blocks creating a small set of resource types without a
#      Project tag. New blocking behavior — defaults false so
#      it can be dry-run reviewed before flipping on.
#
# WHY THIS IS NEEDED:
# default_tags on each environment's provider block already
# tags everything Terraform creates. Neither control here
# re-does that — they exist as defense-in-depth against
# resources created outside Terraform (console, CLI, another
# tool) that would otherwise carry no tags at all.
# ============================================================

resource "aws_organizations_policy" "required_tags" {
  count = var.deploy_tag_policy ? 1 : 0

  name        = "${var.project_prefix}-required-tags"
  description = "Standardizes allowed values for Project, Environment, ManagedBy, and DataClass tags. Advisory only — surfaces non-compliant resources in compliance reports, does not block resource creation."
  type        = "TAG_POLICY"

  content = jsonencode({
    tags = {
      Project = {
        tag_value = {
          "@@assign" = ["BOA-AMEX-TechResolved"]
        }
        enforced_for = {
          "@@assign" = ["s3:bucket", "ec2:instance", "rds:db"]
        }
      }
      Environment = {
        tag_value = {
          "@@assign" = [
            "Management", "SecurityTooling", "PCI-CDE", "CoreBanking",
            "Dev", "Pipeline", "FraudDetection", "DataAnalytics",
            "BIReporting", "CustomerPortal", "1-Foundation"
          ]
        }
        enforced_for = {
          "@@assign" = ["s3:bucket", "ec2:instance", "rds:db"]
        }
      }
      ManagedBy = {
        tag_value = {
          "@@assign" = ["Terraform", "Manual"]
        }
      }
      DataClass = {
        tag_value = {
          "@@assign" = [
            "Restricted-CardholderData", "Restricted-FinancialData",
            "Confidential", "Internal", "Public"
          ]
        }
      }
    }
  })

  tags = merge(var.common_tags, {
    Name       = "${var.project_prefix}-required-tags"
    PolicyType = "Advisory"
  })
}

resource "aws_organizations_policy_attachment" "required_tags_root" {
  count     = var.deploy_tag_policy ? 1 : 0
  policy_id = aws_organizations_policy.required_tags[0].id
  target_id = var.root_id
}

# -----------------------------------------------------------
# SCP — DENY UNTAGGED RESOURCE CREATION
# Blocks creating S3 buckets, EC2 instances, and RDS instances
# without a Project tag. Starts narrow (one required tag) to
# minimize break-risk — widen to Environment/DataClass once a
# dry-run confirms no legitimate workflow creates these
# resource types untagged. Applied only to Production and
# NonProduction OUs — Security and Compliance OUs are excluded
# so this can never interfere with break-glass or audit tooling.
# -----------------------------------------------------------
resource "aws_organizations_policy" "deny_untagged_resource_creation" {
  count = var.deploy_tag_enforcement_scp ? 1 : 0

  name        = "${var.project_prefix}-deny-untagged-resource-creation"
  description = "Denies creating S3 buckets, EC2 instances, and RDS instances without a Project tag. Defense-in-depth against resources created outside Terraform. Applied to Production and NonProduction OUs only."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyUntaggedS3Create"
        Effect   = "Deny"
        Action   = "s3:CreateBucket"
        Resource = "*"
        Condition = {
          Null = {
            "aws:RequestTag/Project" = "true"
          }
        }
      },
      {
        Sid      = "DenyUntaggedEC2Create"
        Effect   = "Deny"
        Action   = "ec2:RunInstances"
        Resource = "*"
        Condition = {
          Null = {
            "aws:RequestTag/Project" = "true"
          }
        }
      },
      {
        Sid      = "DenyUntaggedRDSCreate"
        Effect   = "Deny"
        Action   = "rds:CreateDBInstance"
        Resource = "*"
        Condition = {
          Null = {
            "aws:RequestTag/Project" = "true"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.project_prefix}-deny-untagged-resource-creation"
    SCPType = "Preventive"
  })
}

resource "aws_organizations_policy_attachment" "deny_untagged_resource_creation_production" {
  count     = var.deploy_tag_enforcement_scp && var.production_ou_id != "" ? 1 : 0
  policy_id = aws_organizations_policy.deny_untagged_resource_creation[0].id
  target_id = var.production_ou_id
}

resource "aws_organizations_policy_attachment" "deny_untagged_resource_creation_non_production" {
  count     = var.deploy_tag_enforcement_scp && var.non_production_ou_id != "" ? 1 : 0
  policy_id = aws_organizations_policy.deny_untagged_resource_creation[0].id
  target_id = var.non_production_ou_id
}
