locals {
  output_attributes = {}
  output_interfaces = {
    cluster = {
      endpoint          = "${ovh_cloud_project_database.valkey.endpoints[0].domain}:${ovh_cloud_project_database.valkey.endpoints[0].port}"
      connection_string = format("rediss://%s:%s@%s:%d", ovh_cloud_project_database_valkey_user.app_user.name, ovh_cloud_project_database_valkey_user.app_user.password, ovh_cloud_project_database.valkey.endpoints[0].domain, ovh_cloud_project_database.valkey.endpoints[0].port)
      auth_token        = ovh_cloud_project_database_valkey_user.app_user.password
      port              = tostring(ovh_cloud_project_database.valkey.endpoints[0].port)
      secrets           = ["auth_token", "connection_string"]
    }
  }
}
