locals {
  output_attributes = {
    server_ca_certs = sensitive(local.enable_tls ? google_redis_instance.main.server_ca_certs : [])
    secrets         = ["server_ca_certs"]
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
      secrets = ["auth_token", "connection_string"]
    }
  }
}