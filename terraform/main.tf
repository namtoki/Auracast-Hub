# Auracast Hub - Terraform Main Configuration
# AWS Infrastructure for Auracast Assistant App

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.30"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Auracast"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# ============================================================================
# Local Values
# ============================================================================

locals {
  name_prefix = "auracast-${var.environment}"

  common_tags = {
    Project     = "Auracast"
    Environment = var.environment
  }
}

# ============================================================================
# Modules
# ============================================================================

# Authentication Module (Cognito)
module "auth" {
  source = "./modules/auth"

  name_prefix             = local.name_prefix
  environment             = var.environment
  callback_urls           = var.cognito_callback_urls
  logout_urls             = var.cognito_logout_urls
  google_client_id        = var.google_client_id
  google_client_secret    = var.google_client_secret
  apple_client_id         = var.apple_client_id
  apple_team_id           = var.apple_team_id
  apple_key_id            = var.apple_key_id
  apple_private_key       = var.apple_private_key
  post_confirmation_lambda_arn = module.api.post_confirmation_lambda_arn
}

# Database Module (DynamoDB)
module "database" {
  source = "./modules/database"

  name_prefix = local.name_prefix
  environment = var.environment
}

# API Module (API Gateway, Lambda)
module "api" {
  source = "./modules/api"

  name_prefix          = local.name_prefix
  environment          = var.environment
  dynamodb_table_name  = module.database.main_table_name
  dynamodb_table_arn   = module.database.main_table_arn
  cognito_user_pool_id = module.auth.user_pool_id
  cognito_user_pool_arn = module.auth.user_pool_arn
  redis_endpoint       = module.realtime.redis_endpoint
  redis_port           = module.realtime.redis_port
  opensearch_endpoint  = module.analytics.opensearch_endpoint
  eventbridge_bus_arn  = module.analytics.eventbridge_bus_arn
}

# Analytics Module (Personalize, Comprehend, OpenSearch, Kinesis)
module "analytics" {
  source = "./modules/analytics"

  name_prefix         = local.name_prefix
  environment         = var.environment
  dynamodb_table_arn  = module.database.main_table_arn
  vpc_id              = var.vpc_id
  subnet_ids          = var.private_subnet_ids
}

# Realtime Module (ElastiCache, WebSocket API, AppSync)
module "realtime" {
  source = "./modules/realtime"

  name_prefix              = local.name_prefix
  environment              = var.environment
  vpc_id                   = var.vpc_id
  subnet_ids               = var.private_subnet_ids
  dynamodb_table_name      = module.database.main_table_name
  dynamodb_table_arn       = module.database.main_table_arn
  cognito_user_pool_id     = module.auth.user_pool_id
  eventbridge_bus_arn      = module.analytics.eventbridge_bus_arn
}

# Location Module (Amazon Location Service)
module "location" {
  source = "./modules/location"

  name_prefix = local.name_prefix
  environment = var.environment
}
