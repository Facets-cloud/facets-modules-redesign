# Local values for output structure
locals {
  # Cluster identifier - must be <= 40 characters for AWS ElastiCache
  # Use a hash-based approach to ensure uniqueness while staying within limits
  cluster_id = substr(
    "${var.instance_name}-${substr(md5("${var.instance_name}-${var.environment.unique_name}"), 0, 8)}",
    0,
    40
  )

  # Primary endpoint for connecting to Redis
  # For single node: use primary_endpoint_address
  # For cluster mode: use configuration_endpoint_address if available
  primary_endpoint = coalesce(
    aws_elasticache_replication_group.redis.primary_endpoint_address,
    aws_elasticache_replication_group.redis.configuration_endpoint_address
  )

  # Port number
  redis_port = aws_elasticache_replication_group.redis.port

  # Auth token for secure connections
  auth_token = random_password.redis_auth_token.result
}