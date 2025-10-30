locals {
  output_attributes = {}
  output_interfaces = {
    reader = {
      host              = local.reader_endpoint
      username          = local.master_username
      password          = local.master_password != null ? local.master_password : "imported-password-managed-externally"
      connection_string = local.master_password != null ? "mysql://${local.master_username}:${local.master_password}@${local.reader_endpoint}:${local.mysql_port}/${local.database_name}" : "mysql://${local.master_username}:PASSWORD_MANAGED_EXTERNALLY@${local.reader_endpoint}:${local.mysql_port}/${local.database_name}"
      port              = local.mysql_port
      database          = local.database_name
    }
    writer = {
      host              = local.master_endpoint
      username          = local.master_username
      password          = local.master_password != null ? local.master_password : "imported-password-managed-externally"
      connection_string = local.master_password != null ? "mysql://${local.master_username}:${local.master_password}@${local.master_endpoint}:${local.mysql_port}/${local.database_name}" : "mysql://${local.master_username}:PASSWORD_MANAGED_EXTERNALLY@${local.master_endpoint}:${local.mysql_port}/${local.database_name}"
      port              = local.mysql_port
      database          = local.database_name
    }
  }
}