# ============================================================
# variables.tf — Module input variables
# Module: config-conformance-packs
# ============================================================

variable "project_prefix" {
  description = "Short prefix for resource naming."
  type        = string
}

variable "deploy_conformance_packs" {
  description = "Create the org-wide Config conformance packs. Defaults false — flip once AWS Config recording is enabled per-account, otherwise packs will show no evaluations."
  type        = bool
  default     = false
}

variable "excluded_accounts" {
  description = "Account IDs to exclude from conformance pack evaluation (e.g. the Audit account, which should have nothing to evaluate)."
  type        = list(string)
  default     = []
}

variable "common_tags" {
  description = "Accepted for calling-convention consistency with other modules. Unused: aws_config_organization_conformance_pack has no tags argument."
  type        = map(string)
  default     = {}
}
