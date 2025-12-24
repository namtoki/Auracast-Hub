# Lambda Functions for SpatialSync Phase 1

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.app_name}-${var.environment}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.app_name}-${var.environment}-lambda-role"
    Environment = var.environment
  }
}

# IAM Policy for Lambda to access DynamoDB
resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  name = "${var.app_name}-${var.environment}-lambda-dynamodb-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.user_settings.arn,
          aws_dynamodb_table.device_profiles.arn,
          aws_dynamodb_table.sessions.arn,
          "${aws_dynamodb_table.device_profiles.arn}/index/*",
          "${aws_dynamodb_table.sessions.arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Lambda Layer for common dependencies (optional)
# resource "aws_lambda_layer_version" "common" {
#   filename            = "lambda_layer.zip"
#   layer_name          = "${var.app_name}-${var.environment}-common-layer"
#   compatible_runtimes = ["python3.11"]
# }

# Settings CRUD Lambda
resource "aws_lambda_function" "settings" {
  function_name = "${var.app_name}-${var.environment}-settings"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 30
  memory_size   = 256

  filename         = data.archive_file.settings_lambda.output_path
  source_code_hash = data.archive_file.settings_lambda.output_base64sha256

  environment {
    variables = {
      USER_SETTINGS_TABLE = aws_dynamodb_table.user_settings.name
      ENVIRONMENT         = var.environment
    }
  }

  tags = {
    Name        = "${var.app_name}-${var.environment}-settings"
    Environment = var.environment
  }
}

# Device Profiles Lambda
resource "aws_lambda_function" "device_profiles" {
  function_name = "${var.app_name}-${var.environment}-device-profiles"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 30
  memory_size   = 256

  filename         = data.archive_file.device_profiles_lambda.output_path
  source_code_hash = data.archive_file.device_profiles_lambda.output_base64sha256

  environment {
    variables = {
      DEVICE_PROFILES_TABLE = aws_dynamodb_table.device_profiles.name
      ENVIRONMENT           = var.environment
    }
  }

  tags = {
    Name        = "${var.app_name}-${var.environment}-device-profiles"
    Environment = var.environment
  }
}

# Sessions Lambda
resource "aws_lambda_function" "sessions" {
  function_name = "${var.app_name}-${var.environment}-sessions"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 30
  memory_size   = 256

  filename         = data.archive_file.sessions_lambda.output_path
  source_code_hash = data.archive_file.sessions_lambda.output_base64sha256

  environment {
    variables = {
      SESSIONS_TABLE = aws_dynamodb_table.sessions.name
      ENVIRONMENT    = var.environment
    }
  }

  tags = {
    Name        = "${var.app_name}-${var.environment}-sessions"
    Environment = var.environment
  }
}

# Create Lambda deployment packages
data "archive_file" "settings_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/settings"
  output_path = "${path.module}/lambda/settings.zip"
}

data "archive_file" "device_profiles_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/device_profiles"
  output_path = "${path.module}/lambda/device_profiles.zip"
}

data "archive_file" "sessions_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/sessions"
  output_path = "${path.module}/lambda/sessions.zip"
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "settings_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.settings.function_name}"
  retention_in_days = 14

  tags = {
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "device_profiles_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.device_profiles.function_name}"
  retention_in_days = 14

  tags = {
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "sessions_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.sessions.function_name}"
  retention_in_days = 14

  tags = {
    Environment = var.environment
  }
}
