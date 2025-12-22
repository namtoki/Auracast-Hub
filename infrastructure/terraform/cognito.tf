# Cognito User Pool
resource "aws_cognito_user_pool" "main" {
  name = "${var.app_name}-${var.environment}-user-pool"

  # Username configuration
  username_attributes      = ["email"]
  auto_verified_attributes = var.cognito_auto_verified_attributes

  # Username case sensitivity
  username_configuration {
    case_sensitive = false
  }

  # Password policy
  password_policy {
    minimum_length                   = var.cognito_password_minimum_length
    require_lowercase                = var.cognito_password_require_lowercase
    require_numbers                  = var.cognito_password_require_numbers
    require_symbols                  = var.cognito_password_require_symbols
    require_uppercase                = var.cognito_password_require_uppercase
    temporary_password_validity_days = 7
  }

  # MFA configuration
  mfa_configuration = var.cognito_mfa_configuration

  software_token_mfa_configuration {
    enabled = var.cognito_mfa_configuration != "OFF"
  }

  # Account recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Schema attributes
  schema {
    name                     = "email"
    attribute_data_type      = "String"
    mutable                  = true
    required                 = true
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  schema {
    name                     = "name"
    attribute_data_type      = "String"
    mutable                  = true
    required                 = false
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  # Email configuration
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # Verification message
  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "Auracast Hub - Verification Code"
    email_message        = "Your verification code is {####}"
  }

  # User pool add-ons
  user_pool_add_ons {
    advanced_security_mode = "AUDIT"
  }

  # Device tracking
  device_configuration {
    challenge_required_on_new_device      = false
    device_only_remembered_on_user_prompt = true
  }

  # Admin create user config
  admin_create_user_config {
    allow_admin_create_user_only = false

    invite_message_template {
      email_subject = "Auracast Hub - Your temporary password"
      email_message = "Your username is {username} and temporary password is {####}."
      sms_message   = "Your username is {username} and temporary password is {####}."
    }
  }

  # Deletion protection
  deletion_protection = var.environment == "prod" ? "ACTIVE" : "INACTIVE"

  tags = {
    Name = "${var.app_name}-${var.environment}-user-pool"
  }
}

# Google Identity Provider
resource "aws_cognito_identity_provider" "google" {
  count         = var.enable_google_login ? 1 : 0
  user_pool_id  = aws_cognito_user_pool.main.id
  provider_name = "Google"
  provider_type = "Google"

  provider_details = {
    client_id        = var.google_client_id
    client_secret    = var.google_client_secret
    authorize_scopes = "profile email openid"
  }

  attribute_mapping = {
    email    = "email"
    name     = "name"
    username = "sub"
  }
}

# Facebook Identity Provider
resource "aws_cognito_identity_provider" "facebook" {
  count         = var.enable_facebook_login ? 1 : 0
  user_pool_id  = aws_cognito_user_pool.main.id
  provider_name = "Facebook"
  provider_type = "Facebook"

  provider_details = {
    client_id        = var.facebook_client_id
    client_secret    = var.facebook_client_secret
    authorize_scopes = "public_profile,email"
  }

  attribute_mapping = {
    email    = "email"
    name     = "name"
    username = "id"
  }
}

# Apple Identity Provider
resource "aws_cognito_identity_provider" "apple" {
  count         = var.enable_apple_login ? 1 : 0
  user_pool_id  = aws_cognito_user_pool.main.id
  provider_name = "SignInWithApple"
  provider_type = "SignInWithApple"

  provider_details = {
    client_id        = var.apple_client_id
    team_id          = var.apple_team_id
    key_id           = var.apple_key_id
    private_key      = var.apple_private_key
    authorize_scopes = "public_profile,email"
  }

  attribute_mapping = {
    email    = "email"
    name     = "name"
    username = "sub"
  }
}

# Cognito User Pool Client (for mobile app)
resource "aws_cognito_user_pool_client" "mobile_client" {
  name         = "${var.app_name}-${var.environment}-mobile-client"
  user_pool_id = aws_cognito_user_pool.main.id

  # Client settings
  generate_secret                      = false # Mobile apps should not use client secret
  prevent_user_existence_errors        = "ENABLED"
  enable_token_revocation              = true
  enable_propagate_additional_user_context_data = false

  # Token validity
  access_token_validity  = 1  # hours
  id_token_validity      = 1  # hours
  refresh_token_validity = 30 # days

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  # Auth flows
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
  ]

  # Supported identity providers
  supported_identity_providers = concat(
    ["COGNITO"],
    var.enable_google_login ? ["Google"] : [],
    var.enable_facebook_login ? ["Facebook"] : [],
    var.enable_apple_login ? ["SignInWithApple"] : []
  )

  depends_on = [
    aws_cognito_identity_provider.google,
    aws_cognito_identity_provider.facebook,
    aws_cognito_identity_provider.apple,
  ]

  # Callback and logout URLs
  callback_urls = var.cognito_callback_urls
  logout_urls   = var.cognito_logout_urls

  # OAuth settings
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes = [
    "email",
    "openid",
    "profile",
  ]

  # Read/Write attributes
  read_attributes = [
    "email",
    "email_verified",
    "name",
    "updated_at",
  ]

  write_attributes = [
    "email",
    "name",
  ]
}

# Cognito Identity Pool (for AWS credentials)
resource "aws_cognito_identity_pool" "main" {
  identity_pool_name               = "${var.app_name}-${var.environment}-identity-pool"
  allow_unauthenticated_identities = false
  allow_classic_flow               = false

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.mobile_client.id
    provider_name           = aws_cognito_user_pool.main.endpoint
    server_side_token_check = false
  }

  tags = {
    Name = "${var.app_name}-${var.environment}-identity-pool"
  }
}

# IAM Role for authenticated users
resource "aws_iam_role" "authenticated" {
  name = "${var.app_name}-${var.environment}-cognito-authenticated"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.main.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "authenticated"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.app_name}-${var.environment}-cognito-authenticated"
  }
}

# IAM Policy for authenticated users
resource "aws_iam_role_policy" "authenticated" {
  name = "${var.app_name}-${var.environment}-cognito-authenticated-policy"
  role = aws_iam_role.authenticated.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cognito-sync:*",
          "cognito-identity:*",
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Role for unauthenticated users (minimal permissions)
resource "aws_iam_role" "unauthenticated" {
  name = "${var.app_name}-${var.environment}-cognito-unauthenticated"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.main.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "unauthenticated"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.app_name}-${var.environment}-cognito-unauthenticated"
  }
}

# IAM Policy for unauthenticated users
resource "aws_iam_role_policy" "unauthenticated" {
  name = "${var.app_name}-${var.environment}-cognito-unauthenticated-policy"
  role = aws_iam_role.unauthenticated.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Deny"
        Action   = "*"
        Resource = "*"
      }
    ]
  })
}

# Identity Pool Role Attachment
resource "aws_cognito_identity_pool_roles_attachment" "main" {
  identity_pool_id = aws_cognito_identity_pool.main.id

  roles = {
    "authenticated"   = aws_iam_role.authenticated.arn
    "unauthenticated" = aws_iam_role.unauthenticated.arn
  }
}

# User Pool Domain (for hosted UI - optional)
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.app_name}-${var.environment}-${random_string.domain_suffix.result}"
  user_pool_id = aws_cognito_user_pool.main.id
}

# Random suffix for domain uniqueness
resource "random_string" "domain_suffix" {
  length  = 8
  special = false
  upper   = false
}
