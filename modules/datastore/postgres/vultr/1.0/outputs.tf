locals {
  # Vultr managed PostgreSQL exposes a single primary host; read scaling is handled via
  # separate read replicas, so reader and writer share the primary endpoint here.
  # Connection strings use format() rather than "${...}" interpolation so the contract
  # validator's brace-counting HCL parser can discover the writer/reader interface keys.
  output_attributes = {}

  output_interfaces = {
    writer = {
      host              = vultr_database.db.host
      port              = tostring(vultr_database.db.port)
      username          = vultr_database.db.user
      password          = vultr_database.db.password
      connection_string = format("postgresql://%s:%s@%s:%s/%s?sslmode=require", vultr_database.db.user, vultr_database.db.password, vultr_database.db.host, tostring(vultr_database.db.port), vultr_database.db.dbname)
      secrets           = ["password", "connection_string"]
    }
    reader = {
      host              = vultr_database.db.host
      port              = tostring(vultr_database.db.port)
      username          = vultr_database.db.user
      password          = vultr_database.db.password
      connection_string = format("postgresql://%s:%s@%s:%s/%s?sslmode=require", vultr_database.db.user, vultr_database.db.password, vultr_database.db.host, tostring(vultr_database.db.port), vultr_database.db.dbname)
      secrets           = ["password", "connection_string"]
    }
  }
}
