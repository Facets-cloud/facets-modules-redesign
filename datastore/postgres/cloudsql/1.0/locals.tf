# Local computations for CloudSQL PostgreSQL module
locals {
  # Primary instance details
  instance_identifier = "${var.instance_name}-${var.environment.unique_name}"
  master_endpoint     = google_sql_database_instance.postgres_instance.private_ip_address
  postgres_port       = 5432
  master_username     = google_sql_user.postgres_user.name
  master_password     = google_sql_user.postgres_user.password
  database_name       = google_sql_database.initial_database.name

  # Read replica endpoints (if any)
  replica_endpoints = var.instance.spec.sizing.read_replica_count > 0 ? [
    for replica in google_sql_database_instance.read_replica :
    replica.private_ip_address
  ] : []

  # Choose read endpoint (prefer replica if available, otherwise master)
  reader_endpoint = length(local.replica_endpoints) > 0 ? local.replica_endpoints[0] : local.master_endpoint
}