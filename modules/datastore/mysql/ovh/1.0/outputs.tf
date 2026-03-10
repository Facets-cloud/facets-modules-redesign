locals {
  output_attributes = {}
  output_interfaces = {
    reader = {
      host              = ovh_cloud_project_database.mysql.endpoints[0].domain
      port              = tostring(ovh_cloud_project_database.mysql.endpoints[0].port)
      username          = ovh_cloud_project_database_user.avnadmin.name
      password          = ovh_cloud_project_database_user.avnadmin.password
      database          = "defaultdb"
      connection_string = format("mysql://%s:%s@%s:%d/defaultdb", ovh_cloud_project_database_user.avnadmin.name, ovh_cloud_project_database_user.avnadmin.password, ovh_cloud_project_database.mysql.endpoints[0].domain, ovh_cloud_project_database.mysql.endpoints[0].port)
      secrets           = ["password", "connection_string"]
    }
    writer = {
      host              = ovh_cloud_project_database.mysql.endpoints[0].domain
      port              = tostring(ovh_cloud_project_database.mysql.endpoints[0].port)
      username          = ovh_cloud_project_database_user.avnadmin.name
      password          = ovh_cloud_project_database_user.avnadmin.password
      database          = "defaultdb"
      connection_string = format("mysql://%s:%s@%s:%d/defaultdb", ovh_cloud_project_database_user.avnadmin.name, ovh_cloud_project_database_user.avnadmin.password, ovh_cloud_project_database.mysql.endpoints[0].domain, ovh_cloud_project_database.mysql.endpoints[0].port)
      secrets           = ["password", "connection_string"]
    }
  }
}
