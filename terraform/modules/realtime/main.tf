# Auracast Hub - Realtime Module (ElastiCache, WebSocket API, AppSync)

# ============================================================================
# Security Group for ElastiCache
# ============================================================================

resource "aws_security_group" "redis" {
  count = var.vpc_id != null ? 1 : 0

  name        = "${var.name_prefix}-redis-sg"
  description = "Security group for ElastiCache Redis"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "Redis access from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-redis-sg"
  }
}

# ============================================================================
# ElastiCache Subnet Group
# ============================================================================

resource "aws_elasticache_subnet_group" "redis" {
  count = var.vpc_id != null ? 1 : 0

  name       = "${var.name_prefix}-redis"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.name_prefix}-redis-subnet-group"
  }
}

# ============================================================================
# ElastiCache Redis Cluster
# ============================================================================

resource "aws_elasticache_cluster" "redis" {
  count = var.vpc_id != null ? 1 : 0

  cluster_id           = "${var.name_prefix}-redis"
  engine               = "redis"
  node_type            = var.redis_node_type
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
  engine_version       = "7.0"

  subnet_group_name  = aws_elasticache_subnet_group.redis[0].name
  security_group_ids = [aws_security_group.redis[0].id]

  snapshot_retention_limit = var.environment == "prod" ? 7 : 0

  tags = {
    Name = "${var.name_prefix}-redis"
  }
}

# ============================================================================
# WebSocket API Gateway
# ============================================================================

resource "aws_apigatewayv2_api" "websocket" {
  name                       = "${var.name_prefix}-websocket"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"

  tags = {
    Name = "${var.name_prefix}-websocket-api"
  }
}

# IAM Role for WebSocket Lambda
resource "aws_iam_role" "websocket_lambda" {
  name = "${var.name_prefix}-websocket-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "websocket_lambda" {
  name = "${var.name_prefix}-websocket-lambda-policy"
  role = aws_iam_role.websocket_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query"
        ]
        Resource = [
          var.dynamodb_table_arn,
          "${var.dynamodb_table_arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "execute-api:ManageConnections"
        ]
        Resource = "${aws_apigatewayv2_api.websocket.execution_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "events:PutEvents"
        ]
        Resource = var.eventbridge_bus_arn
      }
    ]
  })
}

# VPC Configuration for Lambda (if VPC is provided)
resource "aws_iam_role_policy_attachment" "websocket_lambda_vpc" {
  count = var.vpc_id != null ? 1 : 0

  role       = aws_iam_role.websocket_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Connect Handler Lambda
data "archive_file" "websocket_connect" {
  type        = "zip"
  output_path = "${path.module}/files/websocket_connect.zip"

  source {
    content = <<-EOF
import boto3
import os
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['CONNECTIONS_TABLE'])

def handler(event, context):
    connection_id = event['requestContext']['connectionId']

    table.put_item(
        Item={
            'connectionId': connection_id,
            'connectedAt': datetime.utcnow().isoformat(),
        }
    )

    return {'statusCode': 200}
EOF
    filename = "handler.py"
  }
}

resource "aws_lambda_function" "websocket_connect" {
  function_name    = "${var.name_prefix}-ws-connect"
  role             = aws_iam_role.websocket_lambda.arn
  handler          = "handler.handler"
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 256
  filename         = data.archive_file.websocket_connect.output_path
  source_code_hash = data.archive_file.websocket_connect.output_base64sha256

  environment {
    variables = {
      CONNECTIONS_TABLE = "${var.name_prefix}-websocket-connections"
      REDIS_HOST        = var.vpc_id != null ? aws_elasticache_cluster.redis[0].cache_nodes[0].address : ""
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_id != null ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = [aws_security_group.redis[0].id]
    }
  }

  tags = {
    Name = "${var.name_prefix}-ws-connect"
  }
}

# Disconnect Handler Lambda
data "archive_file" "websocket_disconnect" {
  type        = "zip"
  output_path = "${path.module}/files/websocket_disconnect.zip"

  source {
    content = <<-EOF
import boto3
import os

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['CONNECTIONS_TABLE'])

def handler(event, context):
    connection_id = event['requestContext']['connectionId']

    table.delete_item(Key={'connectionId': connection_id})

    return {'statusCode': 200}
EOF
    filename = "handler.py"
  }
}

resource "aws_lambda_function" "websocket_disconnect" {
  function_name    = "${var.name_prefix}-ws-disconnect"
  role             = aws_iam_role.websocket_lambda.arn
  handler          = "handler.handler"
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 256
  filename         = data.archive_file.websocket_disconnect.output_path
  source_code_hash = data.archive_file.websocket_disconnect.output_base64sha256

  environment {
    variables = {
      CONNECTIONS_TABLE = "${var.name_prefix}-websocket-connections"
      REDIS_HOST        = var.vpc_id != null ? aws_elasticache_cluster.redis[0].cache_nodes[0].address : ""
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_id != null ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = [aws_security_group.redis[0].id]
    }
  }

  tags = {
    Name = "${var.name_prefix}-ws-disconnect"
  }
}

# Lambda permissions for API Gateway
resource "aws_lambda_permission" "websocket_connect" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.websocket_connect.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.websocket.execution_arn}/*/*"
}

resource "aws_lambda_permission" "websocket_disconnect" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.websocket_disconnect.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.websocket.execution_arn}/*/*"
}

# API Gateway Integrations
resource "aws_apigatewayv2_integration" "connect" {
  api_id           = aws_apigatewayv2_api.websocket.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.websocket_connect.invoke_arn
}

resource "aws_apigatewayv2_integration" "disconnect" {
  api_id           = aws_apigatewayv2_api.websocket.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.websocket_disconnect.invoke_arn
}

# API Gateway Routes
resource "aws_apigatewayv2_route" "connect" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "$connect"
  target    = "integrations/${aws_apigatewayv2_integration.connect.id}"
}

resource "aws_apigatewayv2_route" "disconnect" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "$disconnect"
  target    = "integrations/${aws_apigatewayv2_integration.disconnect.id}"
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "websocket" {
  api_id      = aws_apigatewayv2_api.websocket.id
  name        = var.environment
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.websocket.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      connectionId   = "$context.connectionId"
      eventType      = "$context.eventType"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
    })
  }

  tags = {
    Name = "${var.name_prefix}-websocket-stage"
  }
}

resource "aws_cloudwatch_log_group" "websocket" {
  name              = "/aws/apigateway/${var.name_prefix}-websocket"
  retention_in_days = 30

  tags = {
    Name = "${var.name_prefix}-websocket-logs"
  }
}

# ============================================================================
# AppSync GraphQL API
# ============================================================================

resource "aws_appsync_graphql_api" "main" {
  name                = "${var.name_prefix}-graphql"
  authentication_type = "AMAZON_COGNITO_USER_POOLS"

  user_pool_config {
    user_pool_id   = var.cognito_user_pool_id
    default_action = "ALLOW"
    aws_region     = data.aws_region.current.name
  }

  additional_authentication_provider {
    authentication_type = "AWS_IAM"
  }

  schema = <<-EOF
type Query {
  getListenerCount(broadcastId: ID!): ListenerStats
  getListenerHistory(broadcastId: ID!, period: StatsPeriod!): [ListenerDataPoint!]!
}

type Mutation {
  updateListenerCount(input: ListenerCountInput!): ListenerUpdate
}

type Subscription {
  onListenerCountChanged(broadcastId: ID!): ListenerUpdate
    @aws_subscribe(mutations: ["updateListenerCount"])
}

type ListenerStats {
  broadcastId: ID!
  currentCount: Int!
  peakToday: Int!
  peakAllTime: Int!
  averageDaily: Float!
}

type ListenerUpdate {
  broadcastId: ID!
  currentCount: Int!
  change: Int!
  timestamp: AWSDateTime!
}

type ListenerDataPoint {
  timestamp: AWSDateTime!
  count: Int!
}

input ListenerCountInput {
  broadcastId: ID!
  currentCount: Int!
  change: Int!
}

enum StatsPeriod {
  HOUR
  DAY
  WEEK
  MONTH
}
EOF

  log_config {
    cloudwatch_logs_role_arn = aws_iam_role.appsync_logs.arn
    field_log_level          = "ERROR"
  }

  tags = {
    Name = "${var.name_prefix}-appsync"
  }
}

data "aws_region" "current" {}

resource "aws_iam_role" "appsync_logs" {
  name = "${var.name_prefix}-appsync-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "appsync.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "appsync_logs" {
  name = "${var.name_prefix}-appsync-logs-policy"
  role = aws_iam_role.appsync_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "arn:aws:logs:*:*:*"
    }]
  })
}
