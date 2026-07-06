locals {
  output_attributes = lookup(var.instance.spec.source, "attributes", {})

  # Pure passthrough of the referenced datastore's mongo contract. Absent fields
  # surface as null; when database_name is set, connection strings and the
  # logical name target that database (query params such as tls / replicaSet are
  # preserved by local.rewrite_db).
  output_interfaces = {
    writer = {
      host              = lookup(local.writer, "host", null)
      port              = lookup(local.writer, "port", null)
      username          = lookup(local.writer, "username", null)
      password          = lookup(local.writer, "password", null)
      connection_string = local.rewrite_db["writer"]
      name              = local.has_database ? local.database_name : lookup(local.writer, "name", null)
      secrets           = lookup(local.writer, "secrets", ["password", "connection_string"])
    }
    reader = {
      host              = lookup(local.reader, "host", null)
      port              = lookup(local.reader, "port", null)
      username          = lookup(local.reader, "username", null)
      password          = lookup(local.reader, "password", null)
      connection_string = local.rewrite_db["reader"]
      name              = local.has_database ? local.database_name : lookup(local.reader, "name", null)
      secrets           = lookup(local.reader, "secrets", ["password", "connection_string"])
    }
    cluster = {
      endpoint          = lookup(local.cluster, "endpoint", null)
      username          = lookup(local.cluster, "username", null)
      password          = lookup(local.cluster, "password", null)
      connection_string = local.rewrite_db["cluster"]
      secrets           = lookup(local.cluster, "secrets", ["password", "connection_string"])
    }
  }
}
