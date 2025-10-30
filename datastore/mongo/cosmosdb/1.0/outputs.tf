locals {
  output_attributes = {}
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