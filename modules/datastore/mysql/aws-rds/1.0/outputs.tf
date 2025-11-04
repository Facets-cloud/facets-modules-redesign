locals {
  output_attributes = {
    instance_id             = aws_db_instance.mysql.id
    instance_arn            = aws_db_instance.mysql.arn
    endpoint                = aws_db_instance.mysql.endpoint
    port                    = aws_db_instance.mysql.port
    database_name           = aws_db_instance.mysql.db_name
    master_username         = aws_db_instance.mysql.username
    master_password         = sensitive(local.is_db_instance_import ? "[IMPORTED-NOT-AVAILABLE]" : local.master_password)
    engine_version          = aws_db_instance.mysql.engine_version
    instance_class          = aws_db_instance.mysql.instance_class
    allocated_storage       = aws_db_instance.mysql.allocated_storage
    multi_az                = aws_db_instance.mysql.multi_az
    backup_retention_period = aws_db_instance.mysql.backup_retention_period
    vpc_security_group_ids  = aws_db_instance.mysql.vpc_security_group_ids
    db_subnet_group_name    = aws_db_instance.mysql.db_subnet_group_name
    read_replica_endpoints  = [for r in aws_db_instance.read_replicas : r.endpoint]
    security_group_source   = local.sg_source
    security_group_id       = local.actual_security_group_id
    secrets                 = ["master_password"]
  }
  output_interfaces = {
    writer = sensitive({
      host              = aws_db_instance.mysql.address
      port              = aws_db_instance.mysql.port
      username          = aws_db_instance.mysql.username
      password          = local.is_db_instance_import ? "[IMPORTED-NOT-AVAILABLE]" : local.master_password
      database          = aws_db_instance.mysql.db_name
      connection_string = local.is_db_instance_import ? "mysql://${aws_db_instance.mysql.username}:[PASSWORD]@${aws_db_instance.mysql.address}:${aws_db_instance.mysql.port}/${aws_db_instance.mysql.db_name}" : "mysql://${aws_db_instance.mysql.username}:${local.master_password}@${aws_db_instance.mysql.address}:${aws_db_instance.mysql.port}/${aws_db_instance.mysql.db_name}"
    })
    reader = sensitive({
      endpoints          = [for idx, r in aws_db_instance.read_replicas : { (idx) = r.endpoint }]
      connection_strings = local.is_db_instance_import ? [for r in aws_db_instance.read_replicas : "mysql://${aws_db_instance.mysql.username}:[PASSWORD]@${r.address}:${r.port}/${aws_db_instance.mysql.db_name}"] : [for r in aws_db_instance.read_replicas : "mysql://${aws_db_instance.mysql.username}:${local.master_password}@${r.address}:${r.port}/${aws_db_instance.mysql.db_name}"]
    })
    secrets = ["writer", "reader"]
  }
}