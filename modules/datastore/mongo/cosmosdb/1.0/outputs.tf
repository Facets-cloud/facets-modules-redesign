locals {
  output_attributes = {}
  output_interfaces = {
    writer = {
      host              = local.cluster_endpoint
      port              = tostring(local.cluster_port)
      username          = local.master_username
      password          = local.master_password
      connection_string = local.connection_string
      name              = local.cosmos_account.name
      secrets           = ["password", "connection_string"]
    }
    reader = {
      host              = local.cluster_endpoint
      port              = tostring(local.cluster_port)
      username          = local.master_username
      password          = local.master_password
      connection_string = local.readonly_connection_string
      name              = local.cosmos_account.name
      secrets           = ["password", "connection_string"]
    }
    cluster = {
      endpoint          = "${local.cluster_endpoint}:${local.cluster_port}"
      username          = local.master_username
      password          = local.master_password
      connection_string = local.connection_string
      secrets           = ["password", "connection_string"]
    }
  }
}