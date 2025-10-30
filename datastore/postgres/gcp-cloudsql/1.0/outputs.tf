locals {
  output_attributes = {}
  output_interfaces = {
    reader = { host = local.reader_endpoint, username = local.master_username, password = local.is_import ? null : local.master_password, connection_string = local.is_import ? null : "postgres://${local.master_username}:${local.master_password}@${local.reader_endpoint}:${local.postgres_port}/${local.database_name}" }
    writer = { host = local.master_endpoint, username = local.master_username, password = local.is_import ? null : local.master_password, connection_string = local.is_import ? null : "postgres://${local.master_username}:${local.master_password}@${local.master_endpoint}:${local.postgres_port}/${local.database_name}" }
  }
}