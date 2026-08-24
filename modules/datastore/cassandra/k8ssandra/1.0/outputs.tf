locals {
  output_attributes = {
    namespace    = local.namespace
    cluster_name = local.cluster_name
    datacenter   = local.datacenter
    service_name = local.service_name
  }

  output_interfaces = {
    cluster = {
      endpoint          = local.endpoint
      port              = tostring(local.cql_port)
      username          = local.admin_username
      password          = sensitive(local.admin_password)
      connection_string = sensitive(local.connection_string)
      endpoints         = local.endpoints
      secrets           = ["password", "connection_string"]
    }
  }
}
