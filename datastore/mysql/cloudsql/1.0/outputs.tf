locals {
  output_attributes = {
    port               = local.mysql_port
    database_name      = local.database_name
    instance_name      = google_sql_database_instance.mysql_instance.name
    replica_names      = var.instance.spec.sizing.read_replica_count > 0 ? [for replica in google_sql_database_instance.read_replica : replica.name] : []
    connection_name    = google_sql_database_instance.mysql_instance.connection_name
    master_password    = local.master_password
    master_username    = local.master_username
    public_ip_address  = google_sql_database_instance.mysql_instance.public_ip_address
    private_ip_address = google_sql_database_instance.mysql_instance.private_ip_address
    read_replica_count = var.instance.spec.sizing.read_replica_count
  }
  output_interfaces = {
    reader = { host = local.reader_endpoint, username = local.master_username, password = local.master_password, connection_string = "mysql://${local.master_username}:${local.master_password}@${local.reader_endpoint}:${local.mysql_port}/${local.database_name}" }
    writer = { host = local.master_endpoint, username = local.master_username, password = local.master_password, connection_string = "mysql://${local.master_username}:${local.master_password}@${local.master_endpoint}:${local.mysql_port}/${local.database_name}" }
  }
}