locals {
  output_attributes = {}
  output_interfaces = {
    cluster = {
      endpoint          = "${ovh_cloud_project_database.mongodb.endpoints[0].domain}:${ovh_cloud_project_database.mongodb.endpoints[0].port}"
      username          = ovh_cloud_project_database_mongodb_user.app_user.name
      password          = ovh_cloud_project_database_mongodb_user.app_user.password
      connection_string = format("mongodb+srv://%s:%s@%s/admin?ssl=true&authSource=admin", ovh_cloud_project_database_mongodb_user.app_user.name, ovh_cloud_project_database_mongodb_user.app_user.password, ovh_cloud_project_database.mongodb.endpoints[0].domain)
      secrets           = ["password", "connection_string"]
    }
    reader = {
      host              = ovh_cloud_project_database.mongodb.endpoints[0].domain
      port              = tostring(ovh_cloud_project_database.mongodb.endpoints[0].port)
      username          = ovh_cloud_project_database_mongodb_user.app_user.name
      password          = ovh_cloud_project_database_mongodb_user.app_user.password
      connection_string = format("mongodb+srv://%s:%s@%s/admin?ssl=true&authSource=admin&readPreference=secondaryPreferred", ovh_cloud_project_database_mongodb_user.app_user.name, ovh_cloud_project_database_mongodb_user.app_user.password, ovh_cloud_project_database.mongodb.endpoints[0].domain)
      name              = "admin"
      secrets           = ["password", "connection_string"]
    }
    writer = {
      host              = ovh_cloud_project_database.mongodb.endpoints[0].domain
      port              = tostring(ovh_cloud_project_database.mongodb.endpoints[0].port)
      username          = ovh_cloud_project_database_mongodb_user.app_user.name
      password          = ovh_cloud_project_database_mongodb_user.app_user.password
      connection_string = format("mongodb+srv://%s:%s@%s/admin?ssl=true&authSource=admin", ovh_cloud_project_database_mongodb_user.app_user.name, ovh_cloud_project_database_mongodb_user.app_user.password, ovh_cloud_project_database.mongodb.endpoints[0].domain)
      name              = "admin"
      secrets           = ["password", "connection_string"]
    }
  }
}
