# Auracast Hub - API Module (API Gateway, Lambda)

# ============================================================================
# IAM Role for Lambda Functions
# ============================================================================

resource "aws_iam_role" "lambda_exec" {
  name = "${var.name_prefix}-lambda-exec"

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

resource "aws_iam_role_policy" "lambda_exec" {
  name = "${var.name_prefix}-lambda-exec-policy"
  role = aws_iam_role.lambda_exec.id

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
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = [
          var.dynamodb_table_arn,
          "${var.dynamodb_table_arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "events:PutEvents"
        ]
        Resource = var.eventbridge_bus_arn
      },
      {
        Effect = "Allow"
        Action = [
          "comprehend:DetectSentiment",
          "comprehend:DetectKeyPhrases",
          "comprehend:DetectEntities"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "personalize-runtime:GetRecommendations",
          "personalize-runtime:GetPersonalizedRanking"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "geo:SearchPlaceIndexForPosition",
          "geo:SearchPlaceIndexForText"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# Lambda Layer (Common Dependencies)
# ============================================================================

resource "aws_lambda_layer_version" "common" {
  layer_name          = "${var.name_prefix}-common-layer"
  description         = "Common dependencies for Lambda functions"
  compatible_runtimes = ["python3.11", "python3.12"]

  # Placeholder - actual layer will be uploaded via CI/CD
  filename = data.archive_file.lambda_layer_placeholder.output_path

  lifecycle {
    ignore_changes = [filename]
  }
}

data "archive_file" "lambda_layer_placeholder" {
  type        = "zip"
  output_path = "${path.module}/files/layer_placeholder.zip"

  source {
    content  = "# Placeholder"
    filename = "python/placeholder.txt"
  }
}

# ============================================================================
# Post Confirmation Lambda (Cognito Trigger)
# ============================================================================

data "archive_file" "post_confirmation" {
  type        = "zip"
  output_path = "${path.module}/files/post_confirmation.zip"

  source {
    content = <<-EOF
import boto3
import json
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('${var.dynamodb_table_name}')
eventbridge = boto3.client('events')

def handler(event, context):
    user_attributes = event['request']['userAttributes']
    user_id = event['userName']

    profile_item = {
        'PK': f'USER#{user_id}',
        'SK': 'PROFILE',
        'userId': user_id,
        'email': user_attributes.get('email'),
        'nickname': user_attributes.get('nickname', ''),
        'locale': user_attributes.get('locale', 'ja-JP'),
        'createdAt': datetime.utcnow().isoformat(),
        'updatedAt': datetime.utcnow().isoformat(),
        'status': 'ACTIVE',
        'GSI1PK': 'USERS',
        'GSI1SK': f'CREATED#{datetime.utcnow().isoformat()}',
    }

    preference_item = {
        'PK': f'USER#{user_id}',
        'SK': 'PREFERENCE',
        'preferredCategories': [],
        'preferredLanguages': ['ja'],
        'notificationEnabled': True,
        'autoPlayEnabled': False,
        'dataCollectionConsent': True,
    }

    with table.batch_writer() as batch:
        batch.put_item(Item=profile_item)
        batch.put_item(Item=preference_item)

    eventbridge.put_events(
        Entries=[{
            'Source': 'auracast.users',
            'DetailType': 'UserRegistered',
            'Detail': json.dumps({
                'userId': user_id,
                'email': user_attributes.get('email'),
                'timestamp': datetime.utcnow().isoformat(),
            }),
            'EventBusName': '${var.name_prefix}-events',
        }]
    )

    return event
EOF
    filename = "handler.py"
  }
}

resource "aws_lambda_function" "post_confirmation" {
  function_name    = "${var.name_prefix}-post-confirmation"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.handler"
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 256
  filename         = data.archive_file.post_confirmation.output_path
  source_code_hash = data.archive_file.post_confirmation.output_base64sha256

  environment {
    variables = {
      DYNAMODB_TABLE    = var.dynamodb_table_name
      EVENTBRIDGE_BUS   = "${var.name_prefix}-events"
    }
  }

  tags = {
    Name = "${var.name_prefix}-post-confirmation"
  }
}

resource "aws_lambda_permission" "cognito_post_confirmation" {
  statement_id  = "AllowCognitoInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.post_confirmation.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = var.cognito_user_pool_arn
}

# ============================================================================
# REST API Gateway
# ============================================================================

resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.name_prefix}-api"
  description = "Auracast Hub REST API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name = "${var.name_prefix}-api"
  }
}

# Cognito Authorizer
resource "aws_api_gateway_authorizer" "cognito" {
  name            = "${var.name_prefix}-cognito-authorizer"
  rest_api_id     = aws_api_gateway_rest_api.main.id
  type            = "COGNITO_USER_POOLS"
  provider_arns   = [var.cognito_user_pool_arn]
  identity_source = "method.request.header.Authorization"
}

# ============================================================================
# /users Resource
# ============================================================================

resource "aws_api_gateway_resource" "users" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "users"
}

resource "aws_api_gateway_resource" "users_me" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.users.id
  path_part   = "me"
}

# ============================================================================
# /broadcasts Resource
# ============================================================================

resource "aws_api_gateway_resource" "broadcasts" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "broadcasts"
}

resource "aws_api_gateway_resource" "broadcasts_nearby" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.broadcasts.id
  path_part   = "nearby"
}

resource "aws_api_gateway_resource" "broadcasts_id" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.broadcasts.id
  path_part   = "{broadcastId}"
}

# ============================================================================
# /recommendations Resource
# ============================================================================

resource "aws_api_gateway_resource" "recommendations" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "recommendations"
}

# ============================================================================
# /reviews Resource
# ============================================================================

resource "aws_api_gateway_resource" "reviews" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "reviews"
}

# ============================================================================
# /events Resource (for analytics)
# ============================================================================

resource "aws_api_gateway_resource" "events" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "events"
}

# ============================================================================
# API Deployment
# ============================================================================

resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.users.id,
      aws_api_gateway_resource.broadcasts.id,
      aws_api_gateway_resource.recommendations.id,
      aws_api_gateway_resource.reviews.id,
      aws_api_gateway_resource.events.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.environment

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  tags = {
    Name = "${var.name_prefix}-api-stage"
  }
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.name_prefix}-api"
  retention_in_days = 30

  tags = {
    Name = "${var.name_prefix}-api-logs"
  }
}
