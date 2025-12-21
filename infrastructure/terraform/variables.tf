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
