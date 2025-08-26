locals {
  output_attributes = {
    arn                     = local.mysql_instance.arn
    port                    = local.mysql_instance.port
    endpoint                = local.mysql_instance.endpoint
    instance_id             = local.mysql_instance.id
    storage_type            = local.mysql_instance.storage_type
    database_name           = local.mysql_instance.db_name
    engine_version          = local.mysql_instance.engine_version
    instance_class          = local.mysql_instance.instance_class
    master_username         = local.mysql_instance.username
    allocated_storage       = local.mysql_instance.allocated_storage
    availability_zone       = local.mysql_instance.availability_zone
    security_group_id       = aws_security_group.mysql.id
    subnet_group_name       = aws_db_subnet_group.mysql.name
    secret_manager_arn      = aws_secretsmanager_secret.mysql_password.arn
    read_replica_endpoints  = length(aws_db_instance.read_replicas) > 0 ? aws_db_instance.read_replicas[*].endpoint : []
    backup_retention_period = local.mysql_instance.backup_retention_period
  }
  output_interfaces = {
    reader = {
      host              = length(aws_db_instance.read_replicas) > 0 ? aws_db_instance.read_replicas[0].endpoint : local.mysql_instance.endpoint
      password          = local.master_password
      username          = local.mysql_instance.username
      connection_string = length(aws_db_instance.read_replicas) > 0 ? format("mysql://%s:%s@%s:%d/%s", local.mysql_instance.username, local.master_password, aws_db_instance.read_replicas[0].endpoint, local.mysql_instance.port, local.mysql_instance.db_name) : format("mysql://%s:%s@%s:%d/%s", local.mysql_instance.username, local.master_password, local.mysql_instance.endpoint, local.mysql_instance.port, local.mysql_instance.db_name)
    }
    writer = {
      host              = local.mysql_instance.endpoint
      password          = local.master_password
      username          = local.mysql_instance.username
      connection_string = format("mysql://%s:%s@%s:%d/%s", local.mysql_instance.username, local.master_password, local.mysql_instance.endpoint, local.mysql_instance.port, local.mysql_instance.db_name)
    }
  }
}