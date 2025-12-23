# Auth Module Variables

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "callback_urls" {
  description = "Callback URLs for OAuth"
  type        = list(string)
}

variable "logout_urls" {
  description = "Logout URLs for OAuth"
  type        = list(string)
}

variable "google_client_id" {
  description = "Google OAuth client ID"
  type        = string
  default     = ""
}

variable "google_client_secret" {
  description = "Google OAuth client secret"
  type        = string
  default     = ""
  sensitive   = true
}

variable "apple_client_id" {
  description = "Apple OAuth client ID"
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
  description = "Apple private key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "post_confirmation_lambda_arn" {
  description = "ARN of post confirmation Lambda function"
  type        = string
  default     = ""
}
