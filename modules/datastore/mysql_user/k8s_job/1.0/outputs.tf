locals {
  output_attributes = {
    namespace   = local.namespace
    job_name    = local.job_name
    databases   = local.databases
    auth_plugin = local.auth_plugin
  }

  output_interfaces = {
    user = {
      username = local.username
      password = random_password.user.result
      host     = local.db_host
      port     = local.db_port
      database = length(local.databases) > 0 ? local.databases[0] : lookup(local.writer, "database", "")
      connection_string = format(
        "mysql://%s:%s@%s:%d/%s",
        local.username,
        random_password.user.result,
        local.db_host,
        local.db_port,
        length(local.databases) > 0 ? local.databases[0] : lookup(local.writer, "database", "")
      )
      # connection_string embeds the password, so it is declared secret alongside it.
      # Publishing it unmarked is exactly the defect recorded as BB-SEC-CONNSTR-LEAK-1
      # against the mysql/aws-rds module.
      secrets = ["password", "connection_string"]
    }
  }
}

output "attributes" {
  value = local.output_attributes
}

output "interfaces" {
  value     = local.output_interfaces
  sensitive = true
}
