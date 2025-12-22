variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "auracast-hub"
}

# Cognito settings
variable "cognito_password_minimum_length" {
  description = "Minimum password length"
  type        = number
  default     = 8
}

variable "cognito_password_require_lowercase" {
  description = "Require lowercase in password"
  type        = bool
  default     = true
}

variable "cognito_password_require_numbers" {
  description = "Require numbers in password"
  type        = bool
  default     = true
}

variable "cognito_password_require_symbols" {
  description = "Require symbols in password"
  type        = bool
  default     = false
}

variable "cognito_password_require_uppercase" {
  description = "Require uppercase in password"
  type        = bool
  default     = true
}

variable "cognito_mfa_configuration" {
  description = "MFA configuration (OFF, ON, OPTIONAL)"
  type        = string
  default     = "OPTIONAL"
}

variable "cognito_auto_verified_attributes" {
  description = "Attributes to auto-verify"
  type        = list(string)
  default     = ["email"]
}

variable "cognito_callback_urls" {
  description = "Callback URLs for the app client"
  type        = list(string)
  default     = ["auracasthub://callback"]
}

variable "cognito_logout_urls" {
  description = "Logout URLs for the app client"
  type        = list(string)
  default     = ["auracasthub://signout"]
}

# Social Login settings
variable "enable_google_login" {
  description = "Enable Google federated login"
  type        = bool
  default     = false
}

variable "google_client_id" {
  description = "Google OAuth Client ID"
  type        = string
  default     = ""
  sensitive   = true
}

variable "google_client_secret" {
  description = "Google OAuth Client Secret"
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_facebook_login" {
  description = "Enable Facebook federated login"
  type        = bool
  default     = false
}

variable "facebook_client_id" {
  description = "Facebook App ID"
  type        = string
  default     = ""
  sensitive   = true
}

variable "facebook_client_secret" {
  description = "Facebook App Secret"
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_apple_login" {
  description = "Enable Apple federated login"
  type        = bool
  default     = false
}

variable "apple_client_id" {
  description = "Apple Services ID"
  type        = string
  default     = ""
}

variable "apple_team_id" {
  description = "Apple Team ID"
  type        = string
  default     = ""
}

variable "apple_key_id" {
  description = "Apple Key ID"
  type        = string
  default     = ""
}

variable "apple_private_key" {
  description = "Apple Private Key (PEM format)"
  type        = string
  default     = ""
  sensitive   = true
}
