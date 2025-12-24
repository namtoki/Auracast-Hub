output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN"
  value       = aws_cognito_user_pool.main.arn
}

output "cognito_user_pool_endpoint" {
  description = "Cognito User Pool Endpoint"
  value       = aws_cognito_user_pool.main.endpoint
}

output "cognito_user_pool_client_id" {
  description = "Cognito User Pool Client ID"
  value       = aws_cognito_user_pool_client.mobile_client.id
}

output "cognito_identity_pool_id" {
  description = "Cognito Identity Pool ID"
  value       = aws_cognito_identity_pool.main.id
}

output "cognito_domain" {
  description = "Cognito User Pool Domain"
  value       = aws_cognito_user_pool_domain.main.domain
}

output "cognito_hosted_ui_url" {
  description = "Cognito Hosted UI URL"
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${var.aws_region}.amazoncognito.com"
}

# Flutter app configuration output
output "flutter_amplify_config" {
  description = "Configuration for Flutter Amplify"
  value = {
    region           = var.aws_region
    userPoolId       = aws_cognito_user_pool.main.id
    userPoolClientId = aws_cognito_user_pool_client.mobile_client.id
    identityPoolId   = aws_cognito_identity_pool.main.id
  }
}

# API Gateway outputs
output "api_gateway_url" {
  description = "API Gateway base URL"
  value       = "${aws_api_gateway_stage.prod.invoke_url}"
}

output "api_gateway_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.main.id
}

# DynamoDB table outputs
output "dynamodb_user_settings_table" {
  description = "DynamoDB User Settings table name"
  value       = aws_dynamodb_table.user_settings.name
}

output "dynamodb_device_profiles_table" {
  description = "DynamoDB Device Profiles table name"
  value       = aws_dynamodb_table.device_profiles.name
}

output "dynamodb_sessions_table" {
  description = "DynamoDB Sessions table name"
  value       = aws_dynamodb_table.sessions.name
}

# Lambda function outputs
output "lambda_settings_arn" {
  description = "Settings Lambda function ARN"
  value       = aws_lambda_function.settings.arn
}

output "lambda_device_profiles_arn" {
  description = "Device Profiles Lambda function ARN"
  value       = aws_lambda_function.device_profiles.arn
}

output "lambda_sessions_arn" {
  description = "Sessions Lambda function ARN"
  value       = aws_lambda_function.sessions.arn
}
