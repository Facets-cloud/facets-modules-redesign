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
  {},  # Empty base map
  local.has_external_access ? {
    external_endpoints = jsonencode(local.external_endpoints)
  } : {}
)

  output_interfaces = {
      writer = {
        host              = local.primary_host
        port              = tostring(local.primary_port)
        username          = local.admin_username
        password          = sensitive(local.mongodb_password)
        connection_string = sensitive(local.connection_string)
        name              = local.cluster_name
        secrets           = ["password", "connection_string"]
      }
      reader = {
        host = local.ha_enabled ? "${local.cluster_name}-mongodb-ro.${local.namespace}.svc.cluster.local" : local.primary_host
        port = tostring(local.primary_port)
        username = local.admin_username
        password = sensitive(local.mongodb_password)
        connection_string = sensitive(
          local.password_is_valid ? (
            local.ha_enabled ?
            "mongodb://${local.admin_username}:${local.mongodb_password}@${join(",", local.replica_hosts)}/${local.admin_database}?replicaSet=${local.replica_set_name}&readPreference=secondaryPreferred" :
            "mongodb://${local.admin_username}:${local.mongodb_password}@${local.primary_host}:${local.primary_port}/${local.admin_database}"
          ) : null
        )
        name    = local.cluster_name
        secrets = ["password", "connection_string"]
      }
      cluster = {
        endpoint          = "${local.primary_host}:${local.primary_port}"
        username          = local.admin_username
        password          = sensitive(local.mongodb_password)
        connection_string = sensitive(local.connection_string)
        secrets           = ["password", "connection_string"]
      }
    }
}