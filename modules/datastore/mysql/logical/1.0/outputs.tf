locals {
  source     = var.instance.spec.source
  source_ifc = lookup(local.source, "interfaces", {})

  source_reader = lookup(local.source_ifc, "reader", {})
  source_writer = lookup(local.source_ifc, "writer", {})

  # Optional logical database override. When set, the connection_string is rebuilt
  # to target this database on the same physical host/port; otherwise the source's
  # connection_string and database are re-emitted unchanged.
  override_database = lookup(var.instance.spec, "database_name", null)

  reader_host = lookup(local.source_reader, "host", null)
  reader_port = lookup(local.source_reader, "port", null)
  writer_host = lookup(local.source_writer, "host", null)
  writer_port = lookup(local.source_writer, "port", null)

  reader_database = local.override_database != null ? local.override_database : lookup(local.source_reader, "database", null)
  writer_database = local.override_database != null ? local.override_database : lookup(local.source_writer, "database", null)

  reader_connection_string = local.override_database != null ? format(
    "mysql://%s:%s/%s",
    local.reader_host,
    local.reader_port,
    local.override_database
  ) : lookup(local.source_reader, "connection_string", null)

  writer_connection_string = local.override_database != null ? format(
    "mysql://%s:%s/%s",
    local.writer_host,
    local.writer_port,
    local.override_database
  ) : lookup(local.source_writer, "connection_string", null)

  # Re-emit the @facets/mysql contract from the source.
  output_attributes = lookup(local.source, "attributes", {})

  output_interfaces = {
    reader = {
      host              = local.reader_host
      port              = local.reader_port
      username          = lookup(local.source_reader, "username", null)
      password          = lookup(local.source_reader, "password", null)
      database          = local.reader_database
      connection_string = local.reader_connection_string
      secrets           = lookup(local.source_reader, "secrets", ["password", "connection_string"])
    }
    writer = {
      host              = local.writer_host
      port              = local.writer_port
      username          = lookup(local.source_writer, "username", null)
      password          = lookup(local.source_writer, "password", null)
      database          = local.writer_database
      connection_string = local.writer_connection_string
      secrets           = lookup(local.source_writer, "secrets", ["password", "connection_string"])
    }
  }
}
