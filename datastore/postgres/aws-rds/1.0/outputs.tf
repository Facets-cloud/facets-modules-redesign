locals {
  output_attributes = {
    instance_id             = aws_db_instance.postgres.id
    arn                     = aws_db_instance.postgres.arn
    endpoint                = aws_db_instance.postgres.endpoint
    port                    = aws_db_instance.postgres.port
    database_name           = aws_db_instance.postgres.db_name
    master_username         = aws_db_instance.postgres.username
    availability_zone       = aws_db_instance.postgres.availability_zone
    backup_retention_period = aws_db_instance.postgres.backup_retention_period
    storage_type            = aws_db_instance.postgres.storage_type
    allocated_storage       = aws_db_instance.postgres.allocated_storage
    instance_class          = aws_db_instance.postgres.instance_class
    engine_version          = aws_db_instance.postgres.engine_version
    subnet_group_name       = local.actual_subnet_group_name
    security_group_id       = local.actual_security_group_id
    read_replica_endpoints  = length(aws_db_instance.read_replicas) > 0 ? aws_db_instance.read_replicas[*].endpoint : []
  }
  output_interfaces = {
    reader = {
      host              = length(aws_db_instance.read_replicas) > 0 ? aws_db_instance.read_replicas[0].endpoint : aws_db_instance.postgres.endpoint
      port              = aws_db_instance.postgres.port
      username          = aws_db_instance.postgres.username
      password          = local.is_importing ? var.instance.spec.imports.master_password : local.master_password
      connection_string = format(
        "postgres://%s:%s@%s:%d/%s",
        aws_db_instance.postgres.username,
        local.is_importing ? var.instance.spec.imports.master_password : local.master_password,
        length(aws_db_instance.read_replicas) > 0 ? aws_db_instance.read_replicas[0].endpoint : aws_db_instance.postgres.endpoint,
        aws_db_instance.postgres.port,
        aws_db_instance.postgres.db_name
      )
      secrets           = ["password", "connection_string"]
    }
    writer = {
      host              = aws_db_instance.postgres.endpoint
      username          = aws_db_instance.postgres.username
      password          = local.is_importing ? var.instance.spec.imports.master_password : local.master_password
      connection_string = format(
        "postgres://%s:%s@%s:%d/%s",
        aws_db_instance.postgres.username,
        local.is_importing ? var.instance.spec.imports.master_password : local.master_password,
        aws_db_instance.postgres.endpoint,
        aws_db_instance.postgres.port,
        aws_db_instance.postgres.db_name
      )
      secrets           = ["password", "connection_string"]
    }
  }
}