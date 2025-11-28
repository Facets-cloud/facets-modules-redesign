locals {
  output_attributes = {
    namespace        = local.namespace
    service_name     = local.service_name
    replica_set_name = var.instance_name
    database_name    = local.database_name
    username         = local.admin_username
    password         = sensitive(random_password.mongodb_password.result)
    replica_count    = local.replica_count
    replica_hosts    = local.replica_hosts
    secrets          = ["password"]
  }
  output_interfaces = {
    node1 = {
      username = local.admin_username
      password = random_password.mongodb_password.result
      host     = local.replica_hosts[0]
      port     = 27017
    }
    node2 = {
      username = local.admin_username
      password = random_password.mongodb_password.result
      host     = local.replica_hosts[1]
      port     = 27017
    }
    node3 = {
      username = local.admin_username
      password = random_password.mongodb_password.result
      host     = local.replica_hosts[2]
      port     = 27017
    }
  }
}