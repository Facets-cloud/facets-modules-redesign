locals {
  output_attributes = {}
  # output_attributes = {
  #   host                     = google_redis_instance.main.host
  #   name                     = google_redis_instance.main.name
  #   port                     = google_redis_instance.main.port
  #   tier                     = google_redis_instance.main.tier
  #   region                   = google_redis_instance.main.region
  #   auth_string              = google_redis_instance.main.auth_string
  #   instance_id              = google_redis_instance.main.id
  #   connect_mode             = google_redis_instance.main.connect_mode
  #   display_name             = google_redis_instance.main.display_name
  #   redis_version            = google_redis_instance.main.redis_version
  #   replica_count            = google_redis_instance.main.replica_count
  #   memory_size_gb           = google_redis_instance.main.memory_size_gb
  #   authorized_network       = google_redis_instance.main.authorized_network
  #   read_replicas_mode       = google_redis_instance.main.read_replicas_mode
  #   current_location_id      = google_redis_instance.main.current_location_id
  #   transit_encryption_mode  = google_redis_instance.main.transit_encryption_mode
  #   persistence_iam_identity = google_redis_instance.main.persistence_iam_identity
  # }
  output_interfaces = {
    cluster = {
      port              = tostring(google_redis_instance.main.port)
      endpoint          = "${google_redis_instance.main.host}:${google_redis_instance.main.port}"
      auth_token        = google_redis_instance.main.auth_string
      connection_string = "redis://:${google_redis_instance.main.auth_string}@${google_redis_instance.main.host}:${google_redis_instance.main.port}"
    }
  }
}