locals {
  output_attributes = {}
  # output_attributes = {
  #   cluster_id           = local.cluster_id
  #   primary_endpoint     = local.primary_endpoint
  #   port                 = local.redis_port
  #   auth_token           = sensitive(local.auth_token)
  #   subnet_group_name    = aws_elasticache_subnet_group.redis.name
  #   security_group_id    = aws_security_group.redis.id
  #   replication_group_id = aws_elasticache_replication_group.redis.replication_group_id
  #   secrets              = ["auth_token"]
  # }
  output_interfaces = {
    cluster = sensitive({
      endpoint          = "${local.primary_endpoint}:${local.redis_port}"
      connection_string = var.instance.spec.imports.cluster_id != null && var.instance.spec.imports.cluster_id != "" ? "redis://:YOUR_AUTH_TOKEN@${local.primary_endpoint}:${local.redis_port}" : "redis://:${local.auth_token}@${local.primary_endpoint}:${local.redis_port}"
      auth_token        = local.auth_token
      port              = local.redis_port
    })
    secrets = ["cluster"]
  }
}