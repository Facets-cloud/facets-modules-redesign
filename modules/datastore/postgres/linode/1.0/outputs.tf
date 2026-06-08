locals {
  # The v2 managed-database API exposes a single primary host; read scaling is handled
  # by the platform, so reader and writer share the primary endpoint.
  writer_host = linode_database_postgresql_v2.db.host_primary
  reader_host = linode_database_postgresql_v2.db.host_primary
  db_port     = tostring(linode_database_postgresql_v2.db.port)
  db_user     = linode_database_postgresql_v2.db.root_username
  db_password = linode_database_postgresql_v2.db.root_password

  output_attributes = {}

  output_interfaces = {
    writer = {
      host              = local.writer_host
      port              = local.db_port
      username          = local.db_user
      password          = local.db_password
      connection_string = "postgresql://${local.db_user}:${local.db_password}@${local.writer_host}:${local.db_port}/defaultdb?sslmode=require"
      secrets           = ["password", "connection_string"]
    }
    reader = {
      host              = local.reader_host
      port              = local.db_port
      username          = local.db_user
      password          = local.db_password
      connection_string = "postgresql://${local.db_user}:${local.db_password}@${local.reader_host}:${local.db_port}/defaultdb?sslmode=require"
      secrets           = ["password", "connection_string"]
    }
  }
}
