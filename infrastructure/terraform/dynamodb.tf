# DynamoDB Tables for SpatialSync Phase 1

# User Settings Table
resource "aws_dynamodb_table" "user_settings" {
  name           = "${var.app_name}-${var.environment}-user-settings"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "userId"

  attribute {
    name = "userId"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = false
  }

  point_in_time_recovery {
    enabled = var.environment == "prod"
  }

  tags = {
    Name        = "${var.app_name}-${var.environment}-user-settings"
    Environment = var.environment
  }
}

# Device Profiles Table
resource "aws_dynamodb_table" "device_profiles" {
  name           = "${var.app_name}-${var.environment}-device-profiles"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "deviceId"
  range_key      = "createdAt"

  attribute {
    name = "deviceId"
    type = "S"
  }

  attribute {
    name = "createdAt"
    type = "S"
  }

  attribute {
    name = "model"
    type = "S"
  }

  global_secondary_index {
    name            = "model-index"
    hash_key        = "model"
    range_key       = "createdAt"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = var.environment == "prod"
  }

  tags = {
    Name        = "${var.app_name}-${var.environment}-device-profiles"
    Environment = var.environment
  }
}

# Sessions Table
resource "aws_dynamodb_table" "sessions" {
  name           = "${var.app_name}-${var.environment}-sessions"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "sessionId"

  attribute {
    name = "sessionId"
    type = "S"
  }

  attribute {
    name = "hostDeviceId"
    type = "S"
  }

  global_secondary_index {
    name            = "host-index"
    hash_key        = "hostDeviceId"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = var.environment == "prod"
  }

  tags = {
    Name        = "${var.app_name}-${var.environment}-sessions"
    Environment = var.environment
  }
}
