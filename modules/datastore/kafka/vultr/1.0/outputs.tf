locals {
  output_attributes = {
    cluster_name  = module.name.name
    kafka_version = var.instance.spec.version_config.version
    namespace     = ""
  }

  output_interfaces = {
    cluster = {
      endpoint          = "${vultr_database.db.host}:${vultr_database.db.port}"
      connection_string = "${vultr_database.db.host}:${vultr_database.db.port}"
      endpoints         = { broker = "${vultr_database.db.host}:${vultr_database.db.port}" }
      username          = vultr_database.db.user
      password          = vultr_database.db.password
      secrets           = ["password"]
    }
  }
}
