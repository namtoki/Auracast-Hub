# Database Module Outputs

output "main_table_name" {
  description = "Main DynamoDB table name"
  value       = aws_dynamodb_table.main.name
}

output "main_table_arn" {
  description = "Main DynamoDB table ARN"
  value       = aws_dynamodb_table.main.arn
}

output "main_table_stream_arn" {
  description = "Main DynamoDB table stream ARN"
  value       = aws_dynamodb_table.main.stream_arn
}

output "websocket_connections_table_name" {
  description = "WebSocket connections table name"
  value       = aws_dynamodb_table.websocket_connections.name
}

output "websocket_connections_table_arn" {
  description = "WebSocket connections table ARN"
  value       = aws_dynamodb_table.websocket_connections.arn
}

output "personalize_interactions_table_name" {
  description = "Personalize interactions table name"
  value       = aws_dynamodb_table.personalize_interactions.name
}

output "personalize_interactions_stream_arn" {
  description = "Personalize interactions table stream ARN"
  value       = aws_dynamodb_table.personalize_interactions.stream_arn
}
