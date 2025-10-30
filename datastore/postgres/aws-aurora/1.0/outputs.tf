locals {
  output_attributes = {}
  output_interfaces = {
    reader = {
      host              = aws_rds_cluster.aurora.reader_endpoint
      port              = tostring(aws_rds_cluster.aurora.port)
      password          = local.is_import ? "<imported-password-not-available>" : (local.restore_from_backup ? var.instance.spec.restore_config.master_password : local.master_password)
      username          = aws_rds_cluster.aurora.master_username
      connection_string = local.is_import ? format("postgresql://%s:<password>@%s:%d/%s", aws_rds_cluster.aurora.master_username, aws_rds_cluster.aurora.reader_endpoint, aws_rds_cluster.aurora.port, coalesce(aws_rds_cluster.aurora.database_name, "")) : format("postgresql://%s:%s@%s:%d/%s", aws_rds_cluster.aurora.master_username, local.restore_from_backup ? var.instance.spec.restore_config.master_password : local.master_password, aws_rds_cluster.aurora.reader_endpoint, aws_rds_cluster.aurora.port, aws_rds_cluster.aurora.database_name)
    }
    writer = {
      host              = aws_rds_cluster.aurora.endpoint
      port              = tostring(aws_rds_cluster.aurora.port)
      password          = local.is_import ? "<imported-password-not-available>" : (local.restore_from_backup ? var.instance.spec.restore_config.master_password : local.master_password)
      username          = aws_rds_cluster.aurora.master_username
      connection_string = local.is_import ? format("postgresql://%s:<password>@%s:%d/%s", aws_rds_cluster.aurora.master_username, aws_rds_cluster.aurora.endpoint, aws_rds_cluster.aurora.port, coalesce(aws_rds_cluster.aurora.database_name, "")) : format("postgresql://%s:%s@%s:%d/%s", aws_rds_cluster.aurora.master_username, local.restore_from_backup ? var.instance.spec.restore_config.master_password : local.master_password, aws_rds_cluster.aurora.endpoint, aws_rds_cluster.aurora.port, aws_rds_cluster.aurora.database_name)
    }
  }
}
