locals {
  output_attributes = {}
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
      port              = aws_db_instance.postgres.port
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