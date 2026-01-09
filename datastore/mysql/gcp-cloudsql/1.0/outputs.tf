locals {
  output_attributes = {}
  output_interfaces = {
    reader = {
      host              = local.reader_endpoint
      username          = local.master_username
      password          = var.instance.spec.imports.master_password != null ? var.instance.spec.imports.master_password : local.master_password
      connection_string = "mysql://${local.master_username}:${local.master_password}@${local.reader_endpoint}:${local.mysql_port}/${local.database_name}"
      port              = local.mysql_port
      database          = local.database_name
      secrets           = ["password", "connection_string"]
    }
    writer = {
      host              = local.master_endpoint
      username          = local.master_username
      password          = var.instance.spec.imports.master_password != null ? var.instance.spec.imports.master_password : local.master_password
      connection_string = "mysql://${local.master_username}:${local.master_password}@${local.master_endpoint}:${local.mysql_port}/${local.database_name}"
      port              = local.mysql_port
      database          = local.database_name
      secrets           = ["password", "connection_string"]
    }
  }
}