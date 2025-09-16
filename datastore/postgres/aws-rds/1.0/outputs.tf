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
    writer = sensitive({
      host              = aws_db_instance.postgres.endpoint
      username          = aws_db_instance.postgres.username
      password          = local.is_importing ? "IMPORTED_INSTANCE_PASSWORD_NOT_AVAILABLE" : local.master_password
      connection_string = local.is_importing ? format("postgres://%s@%s:%d/%s", aws_db_instance.postgres.username, aws_db_instance.postgres.endpoint, aws_db_instance.postgres.port, aws_db_instance.postgres.db_name) : format("postgres://%s:%s@%s:%d/%s", aws_db_instance.postgres.username, local.master_password, aws_db_instance.postgres.endpoint, aws_db_instance.postgres.port, aws_db_instance.postgres.db_name)
    })
    reader = sensitive({
      host              = length(aws_db_instance.read_replicas) > 0 ? aws_db_instance.read_replicas[0].endpoint : aws_db_instance.postgres.endpoint
      username          = aws_db_instance.postgres.username
      password          = local.is_importing ? "IMPORTED_INSTANCE_PASSWORD_NOT_AVAILABLE" : local.master_password
      connection_string = local.is_importing ? (length(aws_db_instance.read_replicas) > 0 ? format("postgres://%s@%s:%d/%s", aws_db_instance.postgres.username, aws_db_instance.read_replicas[0].endpoint, aws_db_instance.postgres.port, aws_db_instance.postgres.db_name) : format("postgres://%s@%s:%d/%s", aws_db_instance.postgres.username, aws_db_instance.postgres.endpoint, aws_db_instance.postgres.port, aws_db_instance.postgres.db_name)) : (length(aws_db_instance.read_replicas) > 0 ? format("postgres://%s:%s@%s:%d/%s", aws_db_instance.postgres.username, local.master_password, aws_db_instance.read_replicas[0].endpoint, aws_db_instance.postgres.port, aws_db_instance.postgres.db_name) : format("postgres://%s:%s@%s:%d/%s", aws_db_instance.postgres.username, local.master_password, aws_db_instance.postgres.endpoint, aws_db_instance.postgres.port, aws_db_instance.postgres.db_name))
    })
    secrets = ["writer", "reader"]
  }
}