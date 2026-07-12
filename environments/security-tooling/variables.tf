variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_prefix" {
  type    = string
  default = "boa-amex"
}

variable "security_tooling_account_id" {
  type    = string
  default = "368351959735"
}

variable "management_account_id" {
  type    = string
  default = "682391277575"
}

variable "organization_id" {
  type    = string
  default = "o-tlzn7g9bvb"
}

variable "security_alert_email" {
  type    = string
  default = "emaina@arizona.edu"
}

variable "audit_account_id" {
  type    = string
  default = "445459853572"
}

variable "common_tags" {
  type = map(string)
  default = {
    Project     = "BOA-AMEX-TechResolved"
    ManagedBy   = "Terraform"
    Environment = "SecurityTooling"
    Phase       = "2-SecurityTooling"
  }
}