locals {
  output_attributes = {
    cluster_identifier           = aws_rds_cluster.aurora.cluster_identifier
    cluster_arn                  = aws_rds_cluster.aurora.arn
    cluster_endpoint             = aws_rds_cluster.aurora.endpoint
    reader_endpoint              = aws_rds_cluster.aurora.reader_endpoint
    port                         = aws_rds_cluster.aurora.port
    database_name                = aws_rds_cluster.aurora.database_name
    master_username              = aws_rds_cluster.aurora.master_username
    engine_version               = aws_rds_cluster.aurora.engine_version
    backup_retention_period      = aws_rds_cluster.aurora.backup_retention_period
    preferred_backup_window      = aws_rds_cluster.aurora.preferred_backup_window
    preferred_maintenance_window = aws_rds_cluster.aurora.preferred_maintenance_window
    availability_zones           = aws_rds_cluster.aurora.availability_zones
    subnet_group_name            = aws_db_subnet_group.aurora.name
    security_group_id            = aws_security_group.aurora.id
    writer_instance_id           = length(aws_rds_cluster_instance.aurora_writer) > 0 ? aws_rds_cluster_instance.aurora_writer[0].identifier : null
    reader_instance_ids          = aws_rds_cluster_instance.aurora_readers[*].identifier
  }
  output_interfaces = {
    writer = {
      host              = aws_rds_cluster.aurora.endpoint
      port              = tostring(aws_rds_cluster.aurora.port)
      username          = aws_rds_cluster.aurora.master_username
      password          = local.master_password
      connection_string = format("mysql://%s:%s@%s:%d/%s", aws_rds_cluster.aurora.master_username, local.master_password, aws_rds_cluster.aurora.endpoint, aws_rds_cluster.aurora.port, aws_rds_cluster.aurora.database_name)
    }
    reader = {
      host              = aws_rds_cluster.aurora.reader_endpoint
      port              = tostring(aws_rds_cluster.aurora.port)
      username          = aws_rds_cluster.aurora.master_username
      password          = local.master_password
      connection_string = format("mysql://%s:%s@%s:%d/%s", aws_rds_cluster.aurora.master_username, local.master_password, aws_rds_cluster.aurora.reader_endpoint, aws_rds_cluster.aurora.port, aws_rds_cluster.aurora.database_name)
    }
  }
}