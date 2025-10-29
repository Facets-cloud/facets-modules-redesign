locals {
  output_attributes = {
    identifier                   = aws_rds_cluster.aurora.cluster_identifier
    arn                          = aws_rds_cluster.aurora.arn
    writer_endpoint              = aws_rds_cluster.aurora.endpoint
    reader_endpoint              = aws_rds_cluster.aurora.reader_endpoint
    port                         = aws_rds_cluster.aurora.port
    database_name                = aws_rds_cluster.aurora.database_name
    master_username              = aws_rds_cluster.aurora.master_username
    master_password              = sensitive(local.is_import ? "<imported-password-not-available>" : (local.restore_from_backup ? var.instance.spec.restore_config.master_password : local.master_password))
    engine_version               = aws_rds_cluster.aurora.engine_version
    backup_retention_period      = aws_rds_cluster.aurora.backup_retention_period
    subnet_group_name            = local.is_import ? aws_rds_cluster.aurora.db_subnet_group_name : aws_db_subnet_group.aurora[0].name
    security_group_id            = local.is_import ? null : aws_security_group.aurora[0].id
    # availability_zones           = aws_rds_cluster.aurora.availability_zones
    # writer_instance_id           = length(aws_rds_cluster_instance.aurora_writer) > 0 ? aws_rds_cluster_instance.aurora_writer[0].identifier : null
    # reader_instance_ids          = aws_rds_cluster_instance.aurora_readers[*].identifier
    # preferred_backup_window      = aws_rds_cluster.aurora.preferred_backup_window
    # preferred_maintenance_window = aws_rds_cluster.aurora.preferred_maintenance_window
    is_restored_from_snapshot    = local.restore_from_backup
    is_imported                  = local.is_import
    secrets                      = ["master_password"]
  }
  output_interfaces = {
    reader = {
      username           = aws_rds_cluster.aurora.master_username
      port               = tostring(aws_rds_cluster.aurora.port)
      password           = local.is_import ? "<imported-password-not-available>" : (
        local.restore_from_backup ? var.instance.spec.restore_config.master_password : local.master_password
      )
      database           = aws_rds_cluster.aurora.database_name
      connection_string  = local.is_import ? [
        format(
          "mysql://%s:<password>@%s:%d/%s",
          aws_rds_cluster.aurora.master_username,
          aws_rds_cluster.aurora.reader_endpoint,
          aws_rds_cluster.aurora.port,
          coalesce(aws_rds_cluster.aurora.database_name, "")
        )
      ] : [
        format(
          "mysql://%s:%s@%s:%d/%s",
          aws_rds_cluster.aurora.master_username,
          local.restore_from_backup ? var.instance.spec.restore_config.master_password : local.master_password,
          aws_rds_cluster.aurora.reader_endpoint,
          aws_rds_cluster.aurora.port,
          aws_rds_cluster.aurora.database_name
          )
        ]
      }
    writer = {
      host              = aws_rds_cluster.aurora.endpoint
      port              = tostring(aws_rds_cluster.aurora.port)
      username          = aws_rds_cluster.aurora.master_username
      password          = local.is_import ? "<imported-password-not-available>" : (
        local.restore_from_backup ? var.instance.spec.restore_config.master_password : local.master_password
      )
      database          = aws_rds_cluster.aurora.database_name
      connection_string = local.is_import ? format(
        "mysql://%s:<password>@%s:%d/%s",
        aws_rds_cluster.aurora.master_username,
        aws_rds_cluster.aurora.endpoint,
        aws_rds_cluster.aurora.port,
        coalesce(aws_rds_cluster.aurora.database_name, "")
      ) : format(
        "mysql://%s:%s@%s:%d/%s",
        aws_rds_cluster.aurora.master_username,
        local.restore_from_backup ? var.instance.spec.restore_config.master_password : local.master_password,
        aws_rds_cluster.aurora.endpoint,
        aws_rds_cluster.aurora.port,
        aws_rds_cluster.aurora.database_name
        )
      }
    secrets = ["writer", "reader"]
  }
}