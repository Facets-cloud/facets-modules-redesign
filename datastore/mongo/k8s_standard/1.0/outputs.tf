locals {
  # Build external endpoints map if external access is configured
  external_endpoints = {
    for name, config in local.external_access_config :
    name => {
      host = try(
        length(data.kubernetes_service.external_access[name].status[0].load_balancer[0].ingress) > 0 ?
        coalesce(
          data.kubernetes_service.external_access[name].status[0].load_balancer[0].ingress[0].hostname,
          data.kubernetes_service.external_access[name].status[0].load_balancer[0].ingress[0].ip
        ) : "",
        ""
      )
      port = "27017"
      role = config.role
    }
  }

  output_attributes = merge(
    {
      database_name    = local.admin_database
      max_connections  = "65536"
      namespace        = local.namespace
      password         = sensitive(local.mongodb_password)
      replica_count    = tostring(local.replicas)
      replica_hosts    = join(",", local.replica_hosts)
      replica_set_name = local.replica_set_name
      service_name     = "${local.cluster_name}-mongodb"
      username         = local.admin_username
      secrets          = ["password"]
    },
    # Add external endpoints if configured
    local.has_external_access ? {
      external_endpoints = jsonencode(local.external_endpoints)
    } : {}
  )

  output_interfaces = {
  }
}