variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "lbbs"
}

variable "admin_users" {
  description = "List of LBB admin users"
  type = list(object({
    username = string
    email    = string
    role     = string
  }))
  default = [
    {
      username = "eliud.maina"
      email    = "emaina@arizona.edu"
      role     = "admin"
    },
  ]
}

variable "school_districts" {
  description = "List of school districts"
  type        = list(string)
  default = [
    "Tucson-USD",
    "Sunnyside-USD",
    "Amphitheater-USD",
    "Marana-USD",
    "Catalina-Foothills-USD",
    "Flowing-Wells-USD",
    "Tanque-Verde-USD",
    "Vail-USD",
  ]
}

variable "okta_domain" {
  description = "Okta domain"
  type        = string
  default     = ""
}

variable "okta_client_id" {
  description = "Okta OIDC client ID"
  type        = string
  default     = ""
}

variable "okta_saml_metadata_url" {
  description = "Okta SAML metadata URL"
  type        = string
  default     = ""
}

variable "db_password" {
  description = "PostgreSQL database password"
  type        = string
  sensitive   = true
  default     = "ChangeMe123!"
}

variable "jwt_secret_key" {
  description = "JWT signing key"
  type        = string
  sensitive   = true
  default     = "change-this-in-production"
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "lbbs.lifebeyondthebooksaz.org"
}

variable "alert_email" {
  description = "Email for CloudWatch alerts"
  type        = string
  default     = "emaina@arizona.edu"
  variable "admin_ip_addresses" {
    description = "Admin IP addresses allowed for SSH and monitoring access"
    type        = list(string)
    default = [
      "0.0.0.0/0", # CHANGE THIS to your real IP in production!
      # Example: "72.34.56.78/32" = only YOUR IP address
      # Find your IP: https://whatismyipaddress.com
    ]
  }
}

