locals {
  output_attributes = {}
  output_interfaces = {
    reader = {
      host              = length(aws_db_instance.read_replicas) > 0 ? aws_db_instance.read_replicas[0].endpoint : aws_db_instance.postgres.endpoint
      port              = aws_db_instance.postgres.port
      username          = aws_db_instance.postgres.username
      password          = local.is_importing ? "IMPORTED_INSTANCE_PASSWORD_NOT_AVAILABLE" : local.master_password
      connection_string = local.is_importing ? (length(aws_db_instance.read_replicas) > 0 ? format("postgres://%s@%s:%d/%s", aws_db_instance.postgres.username, aws_db_instance.read_replicas[0].endpoint, aws_db_instance.postgres.port, aws_db_instance.postgres.db_name) : format("postgres://%s@%s:%d/%s", aws_db_instance.postgres.username, aws_db_instance.postgres.endpoint, aws_db_instance.postgres.port, aws_db_instance.postgres.db_name)) : (length(aws_db_instance.read_replicas) > 0 ? format("postgres://%s:%s@%s:%d/%s", aws_db_instance.postgres.username, local.master_password, aws_db_instance.read_replicas[0].endpoint, aws_db_instance.postgres.port, aws_db_instance.postgres.db_name) : format("postgres://%s:%s@%s:%d/%s", aws_db_instance.postgres.username, local.master_password, aws_db_instance.postgres.endpoint, aws_db_instance.postgres.port, aws_db_instance.postgres.db_name))
      secrets           = ["password", "connection_string"]
    }
    writer = {
      host              = aws_db_instance.postgres.endpoint
      port              = aws_db_instance.postgres.port
      username          = aws_db_instance.postgres.username
      password          = local.is_importing ? "IMPORTED_INSTANCE_PASSWORD_NOT_AVAILABLE" : local.master_password
      connection_string = local.is_importing ? format("postgres://%s@%s:%d/%s", aws_db_instance.postgres.username, aws_db_instance.postgres.endpoint, aws_db_instance.postgres.port, aws_db_instance.postgres.db_name) : format("postgres://%s:%s@%s:%d/%s", aws_db_instance.postgres.username, local.master_password, aws_db_instance.postgres.endpoint, aws_db_instance.postgres.port, aws_db_instance.postgres.db_name)
      secrets           = ["password", "connection_string"]
    }
  }
}