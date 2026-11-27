locals {
  source     = var.instance.spec.source
  source_ifc = lookup(local.source, "interfaces", {})

  source_reader = try(local.source_ifc["reader"], {})
  source_writer = try(local.source_ifc["writer"], {})

  # Optional logical database override. When set, the connection_string is rebuilt
  # to target this database on the same physical host/port; otherwise the source's
  # connection_string and database are re-emitted unchanged.
  override_database = try(coalesce(var.instance.spec.database_name, try(jsondecode(var.instance.spec.databases_json)[0], null)), null)

  reader_host = try(coalesce(lookup(local.source_reader, "host", null), lookup(local.source_writer, "host", null)), null)
  reader_port = try(coalesce(lookup(local.source_reader, "port", null), lookup(local.source_writer, "port", null)), null)
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


  declared_user_names = toset(keys(var.instance.spec.user_list))
  default_database    = try(jsondecode(var.instance.spec.databases_json)[0], "")
  user_databases      = { for name in local.declared_user_names : name => try(coalesce(try(var.instance.spec.user_list[name].database, ""), local.writer_database, local.default_database), "") }

  canonical_user_interfaces = {
    for name in local.declared_user_names : name => {
      host              = local.writer_host
      port              = local.writer_port
      username          = name
      password          = sensitive(lookup(jsondecode(var.instance.spec.canonical_passwords_json), name, ""))
      database          = local.user_databases[name]
      connection_string = sensitive(format("mysql://%s:%s@%s:%s/%s", name, lookup(jsondecode(var.instance.spec.canonical_passwords_json), name, ""), local.writer_host, local.writer_port, local.user_databases[name]))
      secrets           = ["password", "connection_string"]
    }
  }

  output_interfaces = merge(local.canonical_user_interfaces, {
    reader = {
      host              = local.reader_host
      port              = local.reader_port
      username          = lookup(local.source_reader, "username", null)
      password          = sensitive(lookup(local.source_reader, "password", null))
      database          = local.reader_database
      connection_string = sensitive(local.reader_connection_string)
      secrets           = distinct(concat(coalesce(lookup(local.source_reader, "secrets", null), []), ["password", "connection_string"]))
    }
    writer = {
      host              = local.writer_host
      port              = local.writer_port
      username          = lookup(local.source_writer, "username", null)
      password          = sensitive(lookup(local.source_writer, "password", null))
      database          = local.writer_database
      connection_string = sensitive(local.writer_connection_string)
      secrets           = distinct(concat(coalesce(lookup(local.source_writer, "secrets", null), []), ["password", "connection_string"]))
    }
  })
}
