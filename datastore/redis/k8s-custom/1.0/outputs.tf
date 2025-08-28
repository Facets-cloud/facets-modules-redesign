locals {
  output_attributes = {
    helm_release_name    = helm_release.redis.name
    namespace            = helm_release.redis.namespace
    master_service_name  = local.master_service_name
    replica_service_name = "null"
    secret_name          = kubernetes_secret.redis_auth.metadata[0].name
    redis_version        = local.redis_version
    architecture         = "\"standalone\""
    port                 = local.redis_port
    storage_size         = local.storage_size
    memory_limit         = local.memory_limit
    cpu_limit            = local.cpu_limit
    replica_count        = "0"
    enable_replication   = "false"
  }
  output_interfaces = {
    master = {
      host              = "${local.master_service_name}.${local.namespace}.svc.cluster.local"
      port              = tostring(local.redis_port)
      password          = local.redis_password
      connection_string = "redis://:${local.redis_password}@${local.master_service_name}.${local.namespace}.svc.cluster.local:${local.redis_port}"
    }
    replica = {
      host              = "${local.master_service_name}.${local.namespace}.svc.cluster.local"
      port              = tostring(local.redis_port)
      password          = local.redis_password
      connection_string = "redis://:${local.redis_password}@${local.master_service_name}.${local.namespace}.svc.cluster.local:${local.redis_port}"
    }
  }
}