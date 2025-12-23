# Auracast Hub - Development Environment Configuration

aws_region  = "ap-northeast-1"
environment = "dev"

# Cognito OAuth URLs
cognito_callback_urls = [
  "auracast://callback",
  "http://localhost:3000/callback"
]
cognito_logout_urls = [
  "auracast://logout",
  "http://localhost:3000/logout"
]

# OAuth providers (set via environment variables or secrets)
# google_client_id     = ""
# google_client_secret = ""
# apple_client_id      = ""
# apple_team_id        = ""
# apple_key_id         = ""
# apple_private_key    = ""

# ElastiCache
redis_node_type = "cache.t3.micro"

# OpenSearch
opensearch_instance_type   = "t3.small.search"
opensearch_instance_count  = 1
opensearch_ebs_volume_size = 10
