locals {
  # Vultr managed MySQL exposes a single primary host; reader and writer share it.
  output_attributes = {}

  output_interfaces = {
    writer = {
      host              = vultr_database.db.host
      port              = vultr_database.db.port
      username          = vultr_database.db.user
      password          = vultr_database.db.password
      database          = vultr_database.db.dbname
      connection_string = format("mysql://%s:%s@%s:%d/%s?ssl-mode=REQUIRED", vultr_database.db.user, vultr_database.db.password, vultr_database.db.host, vultr_database.db.port, vultr_database.db.dbname)
      secrets           = ["password", "connection_string"]
    }
    reader = {
      host              = vultr_database.db.host
      port              = vultr_database.db.port
      username          = vultr_database.db.user
      password          = vultr_database.db.password
      database          = vultr_database.db.dbname
      connection_string = format("mysql://%s:%s@%s:%d/%s?ssl-mode=REQUIRED", vultr_database.db.user, vultr_database.db.password, vultr_database.db.host, vultr_database.db.port, vultr_database.db.dbname)
      secrets           = ["password", "connection_string"]
    }
  }
}
