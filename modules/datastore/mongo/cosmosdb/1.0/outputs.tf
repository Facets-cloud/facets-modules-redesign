locals {
  output_attributes = {
    cluster_identifier              = local.cosmos_account.name
    cluster_endpoint                = local.cluster_endpoint
    cluster_reader_endpoint         = local.cluster_endpoint
    port                            = local.cluster_port
    master_username                 = local.master_username
    master_password                 = sensitive(local.master_password)
    engine_version                  = local.cosmos_account.mongo_server_version
    resource_group_name             = local.cosmos_account.resource_group_name
    location                        = local.cosmos_account.location
    consistency_level               = lower(local.cosmos_account.consistency_policy[0].consistency_level)
    enable_automatic_failover       = local.cosmos_account.automatic_failover_enabled
    enable_multiple_write_locations = local.cosmos_account.multiple_write_locations_enabled
    secrets                         = ["master_password"]
  }
  output_interfaces = {
    writer = sensitive({
      host              = local.cluster_endpoint
      port              = tostring(local.cluster_port)
      username          = local.master_username
      password          = local.master_password
      connection_string = local.connection_string
      name              = local.cosmos_account.name
    })
    reader = sensitive({
      host              = local.cluster_endpoint
      port              = tostring(local.cluster_port)
      username          = local.master_username
      password          = local.master_password
      connection_string = local.readonly_connection_string
      name              = local.cosmos_account.name
    })
    cluster = sensitive({
      endpoint          = "${local.cluster_endpoint}:${local.cluster_port}"
      username          = local.master_username
      password          = local.master_password
      connection_string = local.connection_string
    })
    secrets = ["writer", "reader", "cluster"]
  }
}