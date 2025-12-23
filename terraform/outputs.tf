# Auracast Hub - Terraform Outputs

# ============================================================================
# Authentication Outputs
# ============================================================================

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = module.auth.user_pool_id
}

output "cognito_user_pool_client_id" {
  description = "Cognito User Pool Client ID"
  value       = module.auth.user_pool_client_id
}

output "cognito_identity_pool_id" {
  description = "Cognito Identity Pool ID"
  value       = module.auth.identity_pool_id
}

output "cognito_domain" {
  description = "Cognito hosted UI domain"
  value       = module.auth.domain
}

# ============================================================================
# Database Outputs
# ============================================================================

output "dynamodb_table_name" {
  description = "DynamoDB main table name"
  value       = module.database.main_table_name
}

output "dynamodb_table_arn" {
  description = "DynamoDB main table ARN"
  value       = module.database.main_table_arn
}

# ============================================================================
# API Outputs
# ============================================================================

output "api_gateway_url" {
  description = "API Gateway REST API URL"
  value       = module.api.api_gateway_url
}

output "websocket_api_url" {
  description = "WebSocket API URL"
  value       = module.realtime.websocket_api_url
}

output "appsync_graphql_url" {
  description = "AppSync GraphQL API URL"
  value       = module.realtime.appsync_graphql_url
}

# ============================================================================
# Analytics Outputs
# ============================================================================

output "kinesis_stream_name" {
  description = "Kinesis Data Stream name for events"
  value       = module.analytics.kinesis_stream_name
}

output "opensearch_endpoint" {
  description = "OpenSearch domain endpoint"
  value       = module.analytics.opensearch_endpoint
}

output "eventbridge_bus_name" {
  description = "EventBridge event bus name"
  value       = module.analytics.eventbridge_bus_name
}

# ============================================================================
# Realtime Outputs
# ============================================================================

output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = module.realtime.redis_endpoint
}

# ============================================================================
# Location Outputs
# ============================================================================

output "location_place_index_name" {
  description = "Amazon Location Place Index name"
  value       = module.location.place_index_name
}

output "location_map_name" {
  description = "Amazon Location Map name"
  value       = module.location.map_name
}

# ============================================================================
# Flutter App Configuration Output
# ============================================================================

output "flutter_amplify_config" {
  description = "Configuration for Flutter Amplify"
  value = {
    region              = var.aws_region
    userPoolId          = module.auth.user_pool_id
    userPoolClientId    = module.auth.user_pool_client_id
    identityPoolId      = module.auth.identity_pool_id
    apiGatewayUrl       = module.api.api_gateway_url
    websocketUrl        = module.realtime.websocket_api_url
    graphqlUrl          = module.realtime.appsync_graphql_url
    locationPlaceIndex  = module.location.place_index_name
    locationMapName     = module.location.map_name
  }
  sensitive = false
}
