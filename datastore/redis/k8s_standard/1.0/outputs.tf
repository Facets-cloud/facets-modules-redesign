locals {
  output_attributes = {
    cluster_name      = local.cluster_name
    namespace         = local.namespace
    redis_version     = var.instance.spec.redis_version
    mode              = var.instance.spec.mode
    replicas          = local.replicas
    resource_type     = "redis"
    resource_name     = var.instance_name
    primary_service   = try(data.kubernetes_service.redis_primary.metadata[0].name, "${local.cluster_name}-redis")
    read_service      = local.reader_host != null ? try(kubernetes_service.redis_read[0].metadata[0].name, null) : null
    connection_secret = try(data.kubernetes_secret.redis_credentials.metadata[0].name, "${local.cluster_name}-conn-credential")
    pod_prefix = {
      writer = "${local.cluster_name}-redis"
      reader = local.create_read_service ? "${local.cluster_name}-redis-read" : null
    }
    selectors = {
      redis = {
        "app.kubernetes.io/instance"   = local.cluster_name
        "app.kubernetes.io/managed-by" = "kubeblocks"
        "app.kubernetes.io/name"       = "redis"
      }
    }
  }
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
  }
}