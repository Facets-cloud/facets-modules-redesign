# Local computations for CloudSQL MySQL module
locals {
  # Primary instance details
  master_endpoint = google_sql_database_instance.mysql_instance.private_ip_address
  mysql_port      = 3306
  master_username = google_sql_user.mysql_root_user.name
  master_password = try(google_sql_user.mysql_root_user.password, null)
  database_name   = google_sql_database.initial_database.name

  # Read replica endpoints (if any)
  replica_endpoints = var.instance.spec.sizing.read_replica_count > 0 ? [
    for replica in google_sql_database_instance.read_replica :
    replica.private_ip_address
  ] : []

  # Choose read endpoint (prefer replica if available, otherwise master)
  reader_endpoint = length(local.replica_endpoints) > 0 ? local.replica_endpoints[0] : local.master_endpoint
}