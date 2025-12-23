# Realtime Module Outputs

output "redis_endpoint" {
  description = "Redis endpoint"
  value       = var.vpc_id != null ? aws_elasticache_cluster.redis[0].cache_nodes[0].address : ""
}

output "redis_port" {
  description = "Redis port"
  value       = 6379
}

output "websocket_api_id" {
  description = "WebSocket API ID"
  value       = aws_apigatewayv2_api.websocket.id
}

output "websocket_api_url" {
  description = "WebSocket API URL"
  value       = aws_apigatewayv2_stage.websocket.invoke_url
}

output "appsync_graphql_url" {
  description = "AppSync GraphQL URL"
  value       = aws_appsync_graphql_api.main.uris["GRAPHQL"]
}

output "appsync_api_id" {
  description = "AppSync API ID"
  value       = aws_appsync_graphql_api.main.id
}
