locals {
  auth_token = local.authorization_mode == "AUTH_DISABLED" ? "" : ""

  cluster = {
    host       = local.endpoint_host
    port       = local.endpoint_port
    endpoint   = "${local.endpoint_host}:${local.endpoint_port}"
    auth_token = local.auth_token
    connection_string = local.auth_token == "" ? (
      "${local.scheme}://${local.endpoint_host}:${local.endpoint_port}"
      ) : (
      format("%s://:%s@%s:%s", local.scheme, local.auth_token, local.endpoint_host, local.endpoint_port)
    )
    secrets = ["auth_token", "connection_string"]
  }

  output_attributes = {
    server_ca_certs = sensitive(local.enable_tls ? google_memorystore_instance.main.managed_server_ca : [])
    secrets         = ["server_ca_certs"]
    mode            = google_memorystore_instance.main.mode
    # Cluster mode always has exactly one logical database, whatever the
    # blueprint asked for - report what the instance actually has.
    database_count = local.is_cluster_enabled ? 1 : local.database_count
  }

  output_interfaces = {
    cluster = local.cluster
  }
}
