locals {
  output_attributes = {
    database_name    = local.admin_database
    max_connections  = "65536"
    namespace        = local.namespace
    password         = sensitive(local.mongodb_password)
    replica_count    = tostring(local.replicas)
    replica_hosts    = join(",", local.replica_hosts)
    replica_set_name = local.replica_set_name
    service_name     = "${local.cluster_name}-mongodb"
    username         = local.admin_username
    secrets          = ["password"]
  }
  output_interfaces = {
  }
}