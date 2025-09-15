locals {
  output_attributes = {
    cluster_identifier      = aws_docdb_cluster.main.cluster_identifier
    cluster_endpoint        = local.cluster_endpoint
    cluster_reader_endpoint = aws_docdb_cluster.main.reader_endpoint
    port                    = local.cluster_port
    master_username         = local.master_username
    master_password         = local.master_password
    db_subnet_group_name    = local.is_import ? var.instance.spec.imports.subnet_group_name : aws_docdb_subnet_group.main[0].name
    security_group_id       = local.security_group_id
    engine_version          = aws_docdb_cluster.main.engine_version
    backup_retention_period = aws_docdb_cluster.main.backup_retention_period
    preferred_backup_window = aws_docdb_cluster.main.preferred_backup_window
    cluster_members         = aws_docdb_cluster.main.cluster_members
  }
  output_interfaces = {
    writer = {
      host              = local.cluster_endpoint
      port              = tostring(local.cluster_port)
      username          = local.master_username
      password          = local.master_password
      connection_string = local.is_import ? "*** IMPORTED - CONNECTION STRING NOT ACCESSIBLE ***" : local.connection_string
      name              = aws_docdb_cluster.main.cluster_identifier
    }
    reader = {
      host              = aws_docdb_cluster.main.reader_endpoint
      port              = tostring(local.cluster_port)
      username          = local.master_username
      password          = local.master_password
      connection_string = local.is_import ? "*** IMPORTED - CONNECTION STRING NOT ACCESSIBLE ***" : "mongodb://${local.master_username}:${local.master_password}@${aws_docdb_cluster.main.reader_endpoint}:${local.cluster_port}/?tls=true&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
      name              = aws_docdb_cluster.main.cluster_identifier
    }
    cluster = {
      endpoint          = "${local.cluster_endpoint}:${local.cluster_port}"
      username          = local.master_username
      password          = local.master_password
      connection_string = local.is_import ? "*** IMPORTED - CONNECTION STRING NOT ACCESSIBLE ***" : local.connection_string
    }
  }
}