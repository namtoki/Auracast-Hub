# Auracast Hub - Production Environment Configuration

aws_region  = "ap-northeast-1"
environment = "prod"

# Cognito OAuth URLs
cognito_callback_urls = [
  "auracast://callback",
  "https://app.auracast.example.com/callback"
]
cognito_logout_urls = [
  "auracast://logout",
  "https://app.auracast.example.com/logout"
]

# ElastiCache
redis_node_type = "cache.r6g.large"

# OpenSearch
opensearch_instance_type   = "r6g.large.search"
opensearch_instance_count  = 2
opensearch_ebs_volume_size = 100
