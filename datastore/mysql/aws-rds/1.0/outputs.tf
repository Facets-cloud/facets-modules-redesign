locals {
  output_attributes = {
    identifier               = aws_db_instance.mysql.id
    arn                      = aws_db_instance.mysql.arn
    writer_endpoint          = aws_db_instance.mysql.endpoint
    reader_endpoint          = [for r in aws_db_instance.read_replicas : r.endpoint]
    port                     = aws_db_instance.mysql.port
    database_name            = aws_db_instance.mysql.db_name
    master_username          = aws_db_instance.mysql.username
    master_password          = sensitive(local.is_db_instance_import ? "[IMPORTED-NOT-AVAILABLE]" : local.master_password)
    engine_version           = aws_db_instance.mysql.engine_version
    backup_retention_period  = aws_db_instance.mysql.backup_retention_period
    subnet_group_name        = aws_db_instance.mysql.db_subnet_group_name
    security_group_id        = local.actual_security_group_id
    # vpc_security_group_ids  = aws_db_instance.mysql.vpc_security_group_ids
    # security_group_source   = local.sg_source
    # instance_class          = aws_db_instance.mysql.instance_class
    # allocated_storage       = aws_db_instance.mysql.allocated_storage
    # multi_az                = aws_db_instance.mysql.multi_az
    is_restored_from_snapshot = local.is_restore_operation
    is_imported              = local.is_db_instance_import
    secrets                  = ["master_password"]
  }
  output_interfaces = {
    reader = sensitive({
      username           = aws_db_instance.mysql.username
      port               = aws_db_instance.mysql.port
      password           = local.is_db_instance_import ? "[IMPORTED-NOT-AVAILABLE]" : local.master_password
      database           = aws_db_instance.mysql.db_name
      connection_string = local.is_db_instance_import ? [
        for r in aws_db_instance.read_replicas : 
        "mysql://${aws_db_instance.mysql.username}:[PASSWORD]@${r.address}:${r.port}/${aws_db_instance.mysql.db_name}"
      ] : [
        for r in aws_db_instance.read_replicas : 
        "mysql://${aws_db_instance.mysql.username}:${local.master_password}@${r.address}:${r.port}/${aws_db_instance.mysql.db_name}"
      ]
    })
    writer = sensitive({
      host              = aws_db_instance.mysql.address
      port              = aws_db_instance.mysql.port
      username          = aws_db_instance.mysql.username
      password          = local.is_db_instance_import ? "[IMPORTED-NOT-AVAILABLE]" : local.master_password
      database          = aws_db_instance.mysql.db_name
      connection_string = local.is_db_instance_import ? "mysql://${aws_db_instance.mysql.username}:[PASSWORD]@${aws_db_instance.mysql.address}:${aws_db_instance.mysql.port}/${aws_db_instance.mysql.db_name}" : "mysql://${aws_db_instance.mysql.username}:${local.master_password}@${aws_db_instance.mysql.address}:${aws_db_instance.mysql.port}/${aws_db_instance.mysql.db_name}"
    })
    secrets = ["writer", "reader"]
  }
}