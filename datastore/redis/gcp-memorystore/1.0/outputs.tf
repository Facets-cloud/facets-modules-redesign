locals {
  output_attributes = {}
  output_interfaces = {
    cluster = {
      port              = tostring(google_redis_instance.main.port)
      endpoint          = "${google_redis_instance.main.host}:${google_redis_instance.main.port}"
      auth_token        = google_redis_instance.main.auth_string
      connection_string = "redis://:${google_redis_instance.main.auth_string}@${google_redis_instance.main.host}:${google_redis_instance.main.port}"
    }
  }
}