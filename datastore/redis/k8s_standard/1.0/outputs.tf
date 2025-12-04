locals {
  output_attributes = {}
  output_interfaces = {
    writer = {
      host              = local.writer_host
      port              = local.writer_port
      username          = local.redis_username
      password          = local.redis_password
      connection_string = local.writer_connection_string
      secrets           = ["password", "connection_string"]
    }
    reader = local.create_read_service ? {
      host              = local.reader_host
      port              = local.reader_port
      username          = local.redis_username
      password          = local.redis_password
      connection_string = local.reader_connection_string
      secrets           = ["password", "connection_string"]
      } : {
      host              = local.writer_host
      port              = local.writer_port
      username          = local.redis_username
      password          = local.redis_password
      connection_string = local.writer_connection_string
      secrets           = ["password", "connection_string"]
    }
    cluster = {
      port     = local.redis_port
      # For redis-cluster: clients can connect to any shard's headless service
      # They will auto-discover all nodes via CLUSTER SLOTS command
      # Format: {cluster-name}-shard-{random}-headless
      # Since we can't predict the random suffix, we provide a generic pattern
      # Applications should query for services with label: app.kubernetes.io/instance={cluster-name}
      endpoint = local.mode == "redis-cluster" ? "redis-cluster://${local.cluster_name}.${local.namespace}.svc.cluster.local:${local.redis_port}" : "${local.cluster_name}-redis-redis.${local.namespace}.svc.cluster.local:${local.redis_port}"
      auth_token = local.redis_password
      connection_string = local.mode == "redis-cluster" ? "redis://:${local.redis_password}@${local.cluster_name}-shard-headless.${local.namespace}.svc.cluster.local:${local.redis_port}/0" : "redis://:${local.redis_password}@${local.cluster_name}-redis-redis.${local.namespace}.svc.cluster.local:${local.redis_port}/${local.redis_database}"
      secrets = ["auth_token", "connection_string"]
    }
  }
}