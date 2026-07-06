locals {
  # Full outputs of the referenced postgres datastore.
  source_interfaces = var.instance.spec.source.interfaces
  source_reader     = local.source_interfaces.reader
  source_writer     = local.source_interfaces.writer

  # Optional logical database to re-target the connection string at.
  override_db = lookup(var.instance.spec, "database_name", null)

  # Rebuild the connection string against the overridden logical database when
  # one is supplied, otherwise pass the source connection string through.
  reader_connection_string = local.override_db != null ? format(
    "postgres://%s:%s@%s:%s/%s",
    local.source_reader.username,
    local.source_reader.password,
    local.source_reader.host,
    local.source_reader.port,
    local.override_db,
  ) : local.source_reader.connection_string

  writer_connection_string = local.override_db != null ? format(
    "postgres://%s:%s@%s:%s/%s",
    local.source_writer.username,
    local.source_writer.password,
    local.source_writer.host,
    local.source_writer.port,
    local.override_db,
  ) : local.source_writer.connection_string

  # Passthrough of any source attributes (e.g. db_instance_identifier, arn)
  # when the source datastore emits them.
  output_attributes = lookup(var.instance.spec.source, "attributes", {})

  output_interfaces = {
    reader = {
      host              = local.source_reader.host
      port              = local.source_reader.port
      username          = local.source_reader.username
      password          = local.source_reader.password
      connection_string = local.reader_connection_string
      secrets           = ["password", "connection_string"]
    }
    writer = {
      host              = local.source_writer.host
      port              = local.source_writer.port
      username          = local.source_writer.username
      password          = local.source_writer.password
      connection_string = local.writer_connection_string
      secrets           = ["password", "connection_string"]
    }
  }
}
