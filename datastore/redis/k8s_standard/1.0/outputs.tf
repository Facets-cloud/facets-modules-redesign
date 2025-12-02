locals {
  output_attributes = {}
  output_interfaces = {
    writer = {
      host              = local.writer_host
      port              = local.writer_port
      username          = local.redis_username
      password          = local.redis_password
      connection_string = local.writer_connection_string
      secrets           = ["password", "connection_string"]
    }
    reader = local.create_read_service ? {
      host              = local.reader_host
      port              = local.reader_port
      username          = local.redis_username
      password          = local.redis_password
      connection_string = local.reader_connection_string
      secrets           = ["password", "connection_string"]
      } : {
      host              = local.writer_host
      port              = local.writer_port
      username          = local.redis_username
      password          = local.redis_password
      connection_string = local.writer_connection_string
      secrets           = ["password", "connection_string"]
    }
  }
}