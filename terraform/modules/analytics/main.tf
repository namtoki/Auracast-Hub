# Auracast Hub - Analytics Module (Personalize, Comprehend, OpenSearch, Kinesis)

# ============================================================================
# EventBridge Event Bus
# ============================================================================

resource "aws_cloudwatch_event_bus" "main" {
  name = "${var.name_prefix}-events"

  tags = {
    Name = "${var.name_prefix}-event-bus"
  }
}

# Archive all events for replay
resource "aws_cloudwatch_event_archive" "main" {
  name             = "${var.name_prefix}-events-archive"
  event_source_arn = aws_cloudwatch_event_bus.main.arn
  retention_days   = 30
}

# ============================================================================
# Kinesis Data Stream
# ============================================================================

resource "aws_kinesis_stream" "events" {
  name             = "${var.name_prefix}-events"
  retention_period = 24

  stream_mode_details {
    stream_mode = "ON_DEMAND"
  }

  encryption_type = "KMS"
  kms_key_id      = "alias/aws/kinesis"

  tags = {
    Name = "${var.name_prefix}-kinesis-stream"
  }
}

# ============================================================================
# Kinesis Firehose to S3 (for Personalize data lake)
# ============================================================================

resource "aws_s3_bucket" "data_lake" {
  bucket = "${var.name_prefix}-data-lake-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.name_prefix}-data-lake"
  }
}

resource "aws_s3_bucket_versioning" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    id     = "archive-old-data"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }
}

data "aws_caller_identity" "current" {}

# Firehose IAM Role
resource "aws_iam_role" "firehose" {
  name = "${var.name_prefix}-firehose-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "firehose.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "firehose" {
  name = "${var.name_prefix}-firehose-policy"
  role = aws_iam_role.firehose.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.data_lake.arn,
          "${aws_s3_bucket.data_lake.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kinesis:DescribeStream",
          "kinesis:GetShardIterator",
          "kinesis:GetRecords"
        ]
        Resource = aws_kinesis_stream.events.arn
      }
    ]
  })
}

resource "aws_kinesis_firehose_delivery_stream" "events" {
  name        = "${var.name_prefix}-events-firehose"
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.events.arn
    role_arn           = aws_iam_role.firehose.arn
  }

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose.arn
    bucket_arn = aws_s3_bucket.data_lake.arn
    prefix     = "events/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"

    buffering_size     = 64
    buffering_interval = 60

    compression_format = "GZIP"
  }

  tags = {
    Name = "${var.name_prefix}-firehose"
  }
}

# ============================================================================
# OpenSearch Service
# ============================================================================

resource "aws_opensearch_domain" "main" {
  domain_name    = "${var.name_prefix}-search"
  engine_version = "OpenSearch_2.11"

  cluster_config {
    instance_type          = var.opensearch_instance_type
    instance_count         = var.opensearch_instance_count
    zone_awareness_enabled = var.opensearch_instance_count > 1
  }

  ebs_options {
    ebs_enabled = true
    volume_size = var.opensearch_ebs_volume_size
    volume_type = "gp3"
  }

  encrypt_at_rest {
    enabled = true
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true

    master_user_options {
      master_user_name     = "admin"
      master_user_password = random_password.opensearch_master.result
    }
  }

  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "*"
      }
      Action   = "es:*"
      Resource = "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.name_prefix}-search/*"
    }]
  })

  tags = {
    Name = "${var.name_prefix}-opensearch"
  }
}

resource "random_password" "opensearch_master" {
  length  = 16
  special = true
}

resource "aws_secretsmanager_secret" "opensearch_credentials" {
  name = "${var.name_prefix}/opensearch/master-credentials"

  tags = {
    Name = "${var.name_prefix}-opensearch-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "opensearch_credentials" {
  secret_id = aws_secretsmanager_secret.opensearch_credentials.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.opensearch_master.result
    endpoint = aws_opensearch_domain.main.endpoint
  })
}

data "aws_region" "current" {}

# ============================================================================
# Amazon Personalize
# ============================================================================

resource "aws_iam_role" "personalize" {
  name = "${var.name_prefix}-personalize-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "personalize.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "personalize" {
  name = "${var.name_prefix}-personalize-policy"
  role = aws_iam_role.personalize.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.data_lake.arn,
          "${aws_s3_bucket.data_lake.arn}/*"
        ]
      }
    ]
  })
}

# Note: Personalize Dataset Group, Datasets, Solutions, and Campaigns
# are typically created via CLI/SDK as they require data to be imported first
# The role and S3 bucket are created here for the infrastructure

# ============================================================================
# EventBridge Rules
# ============================================================================

# Rule: User Registered -> Process new user
resource "aws_cloudwatch_event_rule" "user_registered" {
  name           = "${var.name_prefix}-user-registered"
  event_bus_name = aws_cloudwatch_event_bus.main.name

  event_pattern = jsonencode({
    source      = ["auracast.users"]
    detail-type = ["UserRegistered"]
  })

  tags = {
    Name = "${var.name_prefix}-user-registered-rule"
  }
}

# Rule: Review Posted -> Sentiment Analysis
resource "aws_cloudwatch_event_rule" "review_posted" {
  name           = "${var.name_prefix}-review-posted"
  event_bus_name = aws_cloudwatch_event_bus.main.name

  event_pattern = jsonencode({
    source      = ["auracast.reviews"]
    detail-type = ["ReviewPosted"]
  })

  tags = {
    Name = "${var.name_prefix}-review-posted-rule"
  }
}

# Rule: Listener Count Changed -> Update stats
resource "aws_cloudwatch_event_rule" "listener_changed" {
  name           = "${var.name_prefix}-listener-changed"
  event_bus_name = aws_cloudwatch_event_bus.main.name

  event_pattern = jsonencode({
    source      = ["auracast.listeners"]
    detail-type = ["ListenerJoined", "ListenerLeft"]
  })

  tags = {
    Name = "${var.name_prefix}-listener-changed-rule"
  }
}
