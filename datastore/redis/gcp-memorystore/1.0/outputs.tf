locals {
  output_attributes = {
    instance_id             = google_redis_instance.main.id
    instance_name           = google_redis_instance.main.name
    host                    = google_redis_instance.main.host
    port                    = google_redis_instance.main.port
    redis_version           = google_redis_instance.main.redis_version
    tier                    = google_redis_instance.main.tier
    memory_size_gb          = google_redis_instance.main.memory_size_gb
    region                  = local.region
    current_location_id     = google_redis_instance.main.current_location_id
    read_endpoint           = google_redis_instance.main.read_endpoint
    read_endpoint_port      = google_redis_instance.main.read_endpoint_port
    authorized_network      = google_redis_instance.main.authorized_network
    connect_mode            = google_redis_instance.main.connect_mode
    create_time             = google_redis_instance.main.create_time
    transit_encryption_mode = google_redis_instance.main.transit_encryption_mode
    tls_enabled             = local.enable_tls
    server_ca_certs         = sensitive(local.enable_tls ? google_redis_instance.main.server_ca_certs : [])
    auth_string             = sensitive(google_redis_instance.main.auth_string)
    secrets                 = ["server_ca_certs", "auth_string"]
  }
  output_interfaces = {
    cluster = {
      port       = tostring(google_redis_instance.main.port)
      endpoint   = "${google_redis_instance.main.host}:${google_redis_instance.main.port}"
      auth_token = google_redis_instance.main.auth_string
      connection_string = format(
        "%s://:%s@%s:%s",
        local.enable_tls ? "rediss" : "redis",
        google_redis_instance.main.auth_string,
        google_redis_instance.main.host,
        google_redis_instance.main.port
      )
      tls_enabled     = local.enable_tls
      server_ca_certs = local.enable_tls ? google_redis_instance.main.server_ca_certs : []
      secrets         = "[auth_token, connection_string, server_ca_certs]"
    }
  }
}