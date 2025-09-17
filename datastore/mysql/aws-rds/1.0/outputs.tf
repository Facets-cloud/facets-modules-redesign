locals {
  output_attributes = {
    instance_id             = local.mysql_instance.id
    instance_arn            = local.is_db_instance_import ? local.mysql_instance.db_instance_arn : local.mysql_instance.arn
    endpoint                = local.mysql_instance.endpoint
    port                    = local.mysql_instance.port
    database_name           = local.is_db_instance_import ? lookup(local.mysql_instance, "db_name", "") : local.mysql_instance.db_name
    master_username         = local.is_db_instance_import ? local.mysql_instance.master_username : local.mysql_instance.username
    master_password         = sensitive(local.is_db_instance_import ? "[IMPORTED-NOT-AVAILABLE]" : local.master_password)
    engine_version          = local.mysql_instance.engine_version
    instance_class          = local.is_db_instance_import ? local.mysql_instance.db_instance_class : local.mysql_instance.instance_class
    allocated_storage       = local.mysql_instance.allocated_storage
    multi_az                = local.mysql_instance.multi_az
    backup_retention_period = local.mysql_instance.backup_retention_period
    vpc_security_group_ids  = local.is_db_instance_import ? local.mysql_instance.vpc_security_groups : local.mysql_instance.vpc_security_group_ids
    db_subnet_group_name    = local.is_db_instance_import ? local.mysql_instance.db_subnet_group : local.mysql_instance.db_subnet_group_name
    read_replica_endpoints  = [for r in aws_db_instance.read_replicas : r.endpoint]
    secrets                 = ["master_password"]
  }
  output_interfaces = {
    writer = sensitive({
      host              = local.mysql_instance.address
      port              = local.mysql_instance.port
      username          = local.is_db_instance_import ? local.mysql_instance.master_username : local.mysql_instance.username
      password          = local.is_db_instance_import ? "[IMPORTED-NOT-AVAILABLE]" : local.master_password
      database          = local.is_db_instance_import ? lookup(local.mysql_instance, "db_name", "") : local.mysql_instance.db_name
      connection_string = local.is_db_instance_import ? "mysql://${local.mysql_instance.master_username}:[PASSWORD]@${local.mysql_instance.address}:${local.mysql_instance.port}/${lookup(local.mysql_instance, "db_name", "")}" : "mysql://${local.mysql_instance.username}:${local.master_password}@${local.mysql_instance.address}:${local.mysql_instance.port}/${local.mysql_instance.db_name}"
    })
    reader = sensitive({
      endpoints          = [for idx, r in aws_db_instance.read_replicas : { (idx) = r.endpoint }]
      connection_strings = local.is_db_instance_import ? [for r in aws_db_instance.read_replicas : "mysql://${local.mysql_instance.master_username}:[PASSWORD]@${r.address}:${r.port}/${lookup(local.mysql_instance, "db_name", "")}"] : [for r in aws_db_instance.read_replicas : "mysql://${local.mysql_instance.username}:${local.master_password}@${r.address}:${r.port}/${local.mysql_instance.db_name}"]
    })
    secrets = ["writer", "reader"]
  }
}