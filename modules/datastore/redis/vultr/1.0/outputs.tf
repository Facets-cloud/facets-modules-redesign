locals {
  output_attributes = {}
  output_interfaces = {
    cluster = {
      endpoint          = "${vultr_database.db.host}:${vultr_database.db.port}"
      connection_string = format("rediss://%s:%s@%s:%s", vultr_database.db.user, vultr_database.db.password, vultr_database.db.host, tostring(vultr_database.db.port))
      auth_token        = vultr_database.db.password
      port              = tostring(vultr_database.db.port)
      secrets           = ["auth_token", "connection_string"]
    }
  }
}
