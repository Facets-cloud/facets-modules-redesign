locals {
  output_attributes = {}
  output_interfaces = {
    writer = {
      host              = local.writer_host
      port              = local.writer_port
      username          = local.mysql_username
      password          = sensitive(local.mysql_password)
      database          = local.mysql_database
      connection_string = local.writer_connection_string != null ? sensitive(local.writer_connection_string) : null
      secrets           = ["password", "connection_string"]
    }
    reader = local.create_read_service ? {
      host              = local.reader_host
      port              = local.reader_port
      username          = local.mysql_username
      password          = sensitive(local.mysql_password)
      database          = local.mysql_database
      connection_string = local.reader_connection_string != null ? sensitive(local.reader_connection_string) : null
      secrets           = ["password", "connection_string"]
      } : {
      # Fallback to writer if no read replicas
      host              = local.writer_host
      port              = local.writer_port
      username          = local.mysql_username
      password          = sensitive(local.mysql_password)
      database          = local.mysql_database
      connection_string = local.writer_connection_string != null ? sensitive(local.writer_connection_string) : null
      secrets           = ["password", "connection_string"]
    }
  }
}