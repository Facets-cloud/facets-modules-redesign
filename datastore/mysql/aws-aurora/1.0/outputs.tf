locals {
  output_attributes = {
    port                         = aws_rds_cluster.aurora.port
    cluster_arn                  = aws_rds_cluster.aurora.arn
    database_name                = aws_rds_cluster.aurora.database_name
    engine_version               = aws_rds_cluster.aurora.engine_version
    master_username              = aws_rds_cluster.aurora.master_username
    reader_endpoint              = aws_rds_cluster.aurora.reader_endpoint
    cluster_endpoint             = aws_rds_cluster.aurora.endpoint
    security_group_id            = aws_security_group.aurora.id
    subnet_group_name            = aws_db_subnet_group.aurora.name
    availability_zones           = aws_rds_cluster.aurora.availability_zones
    cluster_identifier           = aws_rds_cluster.aurora.cluster_identifier
    writer_instance_id           = length(aws_rds_cluster_instance.aurora_writer) > 0 ? aws_rds_cluster_instance.aurora_writer[0].identifier : null
    reader_instance_ids          = aws_rds_cluster_instance.aurora_readers[*].identifier
    backup_retention_period      = aws_rds_cluster.aurora.backup_retention_period
    preferred_backup_window      = aws_rds_cluster.aurora.preferred_backup_window
    preferred_maintenance_window = aws_rds_cluster.aurora.preferred_maintenance_window
    is_restored_from_snapshot    = local.restore_from_backup
  }
  output_interfaces = {
    reader = {
      host              = aws_rds_cluster.aurora.reader_endpoint
      port              = tostring(aws_rds_cluster.aurora.port)
      password          = local.restore_from_backup ? var.instance.spec.restore_config.master_password : local.master_password
      username          = aws_rds_cluster.aurora.master_username
      connection_string = format("mysql://%s:%s@%s:%d/%s", aws_rds_cluster.aurora.master_username, local.restore_from_backup ? var.instance.spec.restore_config.master_password : local.master_password, aws_rds_cluster.aurora.reader_endpoint, aws_rds_cluster.aurora.port, aws_rds_cluster.aurora.database_name)
    }
    writer = {
      host              = aws_rds_cluster.aurora.endpoint
      port              = tostring(aws_rds_cluster.aurora.port)
      password          = local.restore_from_backup ? var.instance.spec.restore_config.master_password : local.master_password
      username          = aws_rds_cluster.aurora.master_username
      connection_string = format("mysql://%s:%s@%s:%d/%s", aws_rds_cluster.aurora.master_username, local.restore_from_backup ? var.instance.spec.restore_config.master_password : local.master_password, aws_rds_cluster.aurora.endpoint, aws_rds_cluster.aurora.port, aws_rds_cluster.aurora.database_name)
    }
  }
}