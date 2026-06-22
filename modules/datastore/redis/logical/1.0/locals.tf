locals {
  # Full outputs of the selected source @facets/redis datastore, resolved into
  # var.instance.spec.source via the `x-ui-output-type: @facets/redis` spec field.
  source_cluster = lookup(lookup(var.instance.spec.source, "interfaces", {}), "cluster", {})

  source_endpoint          = lookup(local.source_cluster, "endpoint", null)
  source_connection_string = lookup(local.source_cluster, "connection_string", null)
  source_auth_token        = lookup(local.source_cluster, "auth_token", null)
  source_port              = lookup(local.source_cluster, "port", null)
  source_secrets           = lookup(local.source_cluster, "secrets", [])

  db_index = lookup(var.instance.spec, "db_index", 0)

  # Reflect the logical DB index in the connection string. The source
  # @facets/redis connection_string has the form redis://:<auth>@<host>:<port>
  # (no DB path), so we append /<db_index> to target the logical DB. If the
  # source did not expose a connection_string, leave it null.
  connection_string = local.source_connection_string == null ? null : "${local.source_connection_string}/${local.db_index}"
}
