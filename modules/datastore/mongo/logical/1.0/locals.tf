# locals.tf - Computations for the mongo reference (passthrough) flavour.
# No cloud resources are created by this flavour.

locals {
  source_interfaces = lookup(var.instance.spec.source, "interfaces", {})

  writer  = lookup(local.source_interfaces, "writer", {})
  reader  = lookup(local.source_interfaces, "reader", {})
  cluster = lookup(local.source_interfaces, "cluster", {})

  database_name = lookup(var.instance.spec, "database_name", null)
  has_database  = local.database_name != null && local.database_name != ""

  # A mongo connection string looks like:
  #   mongodb://user:pass@host:port/<db>?tls=true&replicaSet=rs0&...
  # To target a logical database we splice <db> between the authority and the
  # query string, preserving the "?..." params (tls / replicaSet / etc.).
  rewrite_db = {
    for k, cs in {
      writer  = lookup(local.writer, "connection_string", null)
      reader  = lookup(local.reader, "connection_string", null)
      cluster = lookup(local.cluster, "connection_string", null)
      } : k => (
      cs == null ? null :
      !local.has_database ? cs :
      length(split("?", cs)) > 1 ?
      format(
        "%s/%s?%s",
        replace(split("?", cs)[0], "/\\/[^/]*$/", ""),
        local.database_name,
        join("?", slice(split("?", cs), 1, length(split("?", cs))))
      ) :
      format("%s/%s", replace(cs, "/\\/[^/]*$/", ""), local.database_name)
    )
  }
}
