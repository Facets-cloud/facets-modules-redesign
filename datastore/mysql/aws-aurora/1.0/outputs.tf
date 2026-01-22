locals {
  output_attributes = {}
  output_interfaces = {
    reader = {
      host     = aws_rds_cluster.aurora.reader_endpoint
      username = aws_rds_cluster.aurora.master_username
      port     = tostring(aws_rds_cluster.aurora.port)
      password = local.restore_from_backup ? var.instance.spec.restore_config.master_password : local.master_password
      database = aws_rds_cluster.aurora.database_name
      connection_string = format(
        "mysql://%s:%s@%s:%d/%s",
        aws_rds_cluster.aurora.master_username,
        local.restore_from_backup ? var.instance.spec.restore_config.master_password : local.master_password,
        aws_rds_cluster.aurora.reader_endpoint,
        aws_rds_cluster.aurora.port,
        aws_rds_cluster.aurora.database_name
      )
      secrets = ["password", "connection_string"]
    }

    writer = {
      host     = aws_rds_cluster.aurora.endpoint
      port     = tostring(aws_rds_cluster.aurora.port)
      username = aws_rds_cluster.aurora.master_username
      password = local.restore_from_backup ? var.instance.spec.restore_config.master_password : local.master_password
      database = aws_rds_cluster.aurora.database_name
      connection_string = format(
        "mysql://%s:%s@%s:%d/%s",
        aws_rds_cluster.aurora.master_username,
        local.restore_from_backup ? var.instance.spec.restore_config.master_password : local.master_password,
        aws_rds_cluster.aurora.endpoint,
        aws_rds_cluster.aurora.port,
        aws_rds_cluster.aurora.database_name
      )
      secrets = ["password", "connection_string"]
    }
  }
}