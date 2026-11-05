locals {
  project_id = coalesce(
    lookup(var.inputs.network.attributes, "project_id", ""),
    lookup(var.inputs.gcp_provider.attributes, "project_id", "")
  )
  region = lookup(var.inputs.network.attributes, "region", "")
  network = coalesce(
    lookup(var.inputs.network.attributes, "vpc_name", "") != "" ? "projects/${local.project_id}/global/networks/${lookup(var.inputs.network.attributes, "vpc_name", "")}" : "",
    lookup(var.inputs.network.attributes, "vpc_self_link", "")
  )

  name_sanitized = lower(replace("${var.instance_name}-${var.environment.unique_name}", "/[^a-zA-Z0-9-]/", "-"))
  instance_id    = substr(trim(local.name_sanitized, "-"), 0, 63)

  mode = lookup(var.instance.spec.version_config, "mode", "CLUSTER_DISABLED")

  # Cluster mode has two spellings in Google's own tooling: the REST API and the
  # docs say CLUSTER_ENABLED, while gcloud (--mode=cluster) and the Terraform
  # provider accept only ["CLUSTER" "CLUSTER_DISABLED" ""]. Passing
  # CLUSTER_ENABLED through fails the plan with
  #   expected mode to be one of ["CLUSTER" "CLUSTER_DISABLED" ""]
  # so accept the API spelling in the blueprint and normalise it here.
  mode_normalized = local.mode == "CLUSTER_ENABLED" ? "CLUSTER" : local.mode

  # Valkey in cluster mode has exactly one logical database (db 0). The API
  # rejects engine_configs.databases on such an instance, so the key must be
  # omitted entirely rather than pinned to "1".
  is_cluster_enabled = local.mode_normalized == "CLUSTER"

  enable_tls         = lookup(var.instance.spec.security, "enable_tls", true)
  authorization_mode = lookup(var.instance.spec.security, "authorization_mode", "AUTH_DISABLED")
  database_count     = lookup(var.instance.spec.engine_config, "database_count", 16)
  psc_policy_name    = lookup(var.inputs.service_connection_policy.attributes, "name", "")
  psc_policy_label   = substr(trim(lower(replace(local.psc_policy_name, "/[^a-zA-Z0-9_-]/", "-")), "-"), 0, 63)

  psc_auto_connections = flatten([
    for endpoint in google_memorystore_instance.main.endpoints : [
      for connection in endpoint.connections : connection.psc_auto_connection
    ]
  ])

  primary_connections = [
    for connection in local.psc_auto_connections : connection
    if try(connection.connection_type, "") == "CONNECTION_TYPE_PRIMARY"
  ]

  discovery_connections = [
    for connection in local.psc_auto_connections : connection
    if try(connection.connection_type, "") == "CONNECTION_TYPE_DISCOVERY"
  ]

  reader_connections = [
    for connection in local.psc_auto_connections : connection
    if try(connection.connection_type, "") == "CONNECTION_TYPE_READER"
  ]

  selected_connection = length(local.primary_connections) > 0 ? local.primary_connections[0] : (
    length(local.discovery_connections) > 0 ? local.discovery_connections[0] : (
      length(local.reader_connections) > 0 ? local.reader_connections[0] : null
    )
  )

  endpoint_host = local.selected_connection == null ? "" : local.selected_connection.ip_address
  endpoint_port = local.selected_connection == null ? "" : tostring(local.selected_connection.port)
  scheme        = local.enable_tls ? "rediss" : "redis"

  # A Facets optional() spec field materialises as NULL rather than being absent,
  # so every read has to survive `backup` itself being null AND the key being
  # missing. try() catches both (attribute access on null is an error), and
  # coalesce supplies the default.
  #
  # Do NOT write this as `backup == null ? {} : backup`: an empty object and a
  # typed object are different types, and terraform rejects the conditional with
  # "Inconsistent conditional result types". `terraform validate` does NOT catch
  # that - it only surfaced at plan time.
  #
  # Default OFF. This module version already backs 11 live instances; defaulting
  # backups on would turn every one of them on at their next release.
  backup_enabled        = coalesce(try(var.instance.spec.backup.enabled, null), false)
  backup_retention_days = coalesce(try(var.instance.spec.backup.retention_days, null), 1)
  backup_start_hour     = coalesce(try(var.instance.spec.backup.start_hour, null), 21)
}
