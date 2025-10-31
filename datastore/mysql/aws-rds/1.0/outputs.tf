locals {
  output_attributes = {}
  output_interfaces = {
    reader = {
      host     = length(aws_db_instance.read_replicas) > 0 ? aws_db_instance.read_replicas[0].address : aws_db_instance.mysql.address
      username = aws_db_instance.mysql.username
      port     = aws_db_instance.mysql.port
      password = local.is_db_instance_import ? "[IMPORTED-NOT-AVAILABLE]" : local.master_password
      database = aws_db_instance.mysql.db_name

      connection_string = local.is_db_instance_import ? (
        length(aws_db_instance.read_replicas) > 0 ?
        format(
          "mysql://%s:[PASSWORD]@%s:%d/%s",
          aws_db_instance.mysql.username,
          aws_db_instance.read_replicas[0].address,
          aws_db_instance.read_replicas[0].port,
          aws_db_instance.mysql.db_name
        ) :
        format(
          "mysql://%s:[PASSWORD]@%s:%d/%s",
          aws_db_instance.mysql.username,
          aws_db_instance.mysql.address,
          aws_db_instance.mysql.port,
          aws_db_instance.mysql.db_name
        )
        ) : (
        length(aws_db_instance.read_replicas) > 0 ?
        format(
          "mysql://%s:%s@%s:%d/%s",
          aws_db_instance.mysql.username,
          local.master_password,
          aws_db_instance.read_replicas[0].address,
          aws_db_instance.read_replicas[0].port,
          aws_db_instance.mysql.db_name
        ) :
        format(
          "mysql://%s:%s@%s:%d/%s",
          aws_db_instance.mysql.username,
          local.master_password,
          aws_db_instance.mysql.address,
          aws_db_instance.mysql.port,
          aws_db_instance.mysql.db_name
        )
      )
    }

    writer = {
      host              = aws_db_instance.mysql.address
      port              = aws_db_instance.mysql.port
      username          = aws_db_instance.mysql.username
      password          = local.is_db_instance_import ? "[IMPORTED-NOT-AVAILABLE]" : local.master_password
      database          = aws_db_instance.mysql.db_name
      connection_string = local.is_db_instance_import ? "mysql://${aws_db_instance.mysql.username}:[PASSWORD]@${aws_db_instance.mysql.address}:${aws_db_instance.mysql.port}/${aws_db_instance.mysql.db_name}" : "mysql://${aws_db_instance.mysql.username}:${local.master_password}@${aws_db_instance.mysql.address}:${aws_db_instance.mysql.port}/${aws_db_instance.mysql.db_name}"
    }
    secrets = ["writer", "reader"]
  }
}