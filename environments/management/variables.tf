variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_prefix" {
  type    = string
  default = "boa-amex"
}

variable "organization_id" {
  type    = string
  default = "o-tlzn7g9bvb"
}

variable "management_account_id" {
  type    = string
  default = "682391277575"
}

variable "security_tooling_account_id" {
  type    = string
  default = "368351959735"
}

variable "common_tags" {
  type = map(string)
  default = {
    Project     = "BOA-AMEX-TechResolved"
    ManagedBy   = "Terraform"
    Environment = "Management"
    Phase       = "1-Foundation"
  }
}