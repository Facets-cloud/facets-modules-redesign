# Local computations for CloudSQL PostgreSQL module
locals {
  # Check if we're importing existing resources
  is_import = var.instance.spec.imports != null && var.instance.spec.imports.instance_id != null

  # Primary instance details - use import ID if provided, otherwise generate new name
  instance_identifier = local.is_import ? var.instance.spec.imports.instance_id : "${var.instance_name}-${var.environment.unique_name}"

  # Extract actual resource names from terraform import addresses
  # Database import format: "projects/PROJECT/instances/INSTANCE/databases/DATABASE_NAME"
  # User import format: "PROJECT/INSTANCE/USER_NAME"
  db_name = local.is_import && var.instance.spec.imports.database_name != null ? (
    # Extract database name from terraform import address
    length(split("/", var.instance.spec.imports.database_name)) > 1 ?
    element(split("/", var.instance.spec.imports.database_name), length(split("/", var.instance.spec.imports.database_name)) - 1) :
    var.instance.spec.imports.database_name
  ) : var.instance.spec.version_config.database_name

  user_name = var.instance.spec.restore_config.restore_from_backup ? var.instance.spec.restore_config.master_username : "postgres"

  # Connection details
  master_endpoint = google_sql_database_instance.postgres_instance.private_ip_address
  postgres_port   = 5432
  master_username = google_sql_user.postgres_user.name
  master_password = google_sql_user.postgres_user.password
  database_name   = google_sql_database.initial_database.name

  # Read replica endpoints (if any)
  replica_endpoints = var.instance.spec.sizing.read_replica_count > 0 ? [
    for replica in google_sql_database_instance.read_replica :
    replica.private_ip_address
  ] : []

  # Choose read endpoint (prefer replica if available, otherwise master)
  reader_endpoint = length(local.replica_endpoints) > 0 ? local.replica_endpoints[0] : local.master_endpoint
}