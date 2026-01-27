# Local computations for CloudSQL MySQL module
locals {
  # Import flag
  import_enabled = lookup(var.instance.spec, "imports", null) != null ? lookup(var.instance.spec.imports, "import_existing", false) : false

  # Primary instance details
  master_endpoint = google_sql_database_instance.mysql_instance.private_ip_address
  mysql_port      = 3306
  master_username = google_sql_user.mysql_root_user.name
  master_password = local.import_enabled && var.instance.spec.imports.master_password != null ? var.instance.spec.imports.master_password : google_sql_user.mysql_root_user.password
  database_name   = google_sql_database.initial_database.name

  # Read replica endpoints (if any)
  replica_endpoints = var.instance.spec.sizing.read_replica_count > 0 ? [
    for replica in google_sql_database_instance.read_replica :
    replica.private_ip_address
  ] : []

  # Choose read endpoint (prefer replica if available, otherwise master)
  reader_endpoint = length(local.replica_endpoints) > 0 ? local.replica_endpoints[0] : local.master_endpoint
}