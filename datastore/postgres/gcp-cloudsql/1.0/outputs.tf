locals {
  output_attributes = {}
  output_interfaces = {
    reader = { 
      host = local.reader_endpoint
      port = local.postgres_port
      username = local.master_username
      password = local.is_import ? var.instance.spec.imports.master_password : local.master_password
      connection_string = "postgres://${local.master_username}:${local.master_password}@${local.reader_endpoint}:${local.postgres_port}/${local.database_name}"
      secrets           = ["password", "connection_string"]
    }
    writer = {
      host = local.master_endpoint
      port = local.postgres_port
      username = local.master_username
      password = local.is_import ? var.instance.spec.imports.master_password : local.master_password
      connection_string = "postgres://${local.master_username}:${local.master_password}@${local.master_endpoint}:${local.postgres_port}/${local.database_name}"
      secrets           = ["password", "connection_string"]
    }
  }
}