locals {
  output_attributes = {}
  output_interfaces = {
    writer = {
      host              = local.cluster_endpoint
      port              = tostring(local.cluster_port)
      username          = local.master_username
      password          = local.master_password
      connection_string = local.connection_string
      name              = aws_docdb_cluster.main.cluster_identifier
      secrets           = ["password", "connection_string"]
    }
    reader = {
      host              = aws_docdb_cluster.main.reader_endpoint
      port              = tostring(local.cluster_port)
      username          = local.master_username
      password          = local.master_password
      connection_string = "mongodb://${local.master_username}:${local.master_password}@${aws_docdb_cluster.main.reader_endpoint}:${local.cluster_port}/?tls=true&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
      name              = aws_docdb_cluster.main.cluster_identifier
      secrets           = ["password", "connection_string"]
    }
    cluster = {
      endpoint          = "${local.cluster_endpoint}:${local.cluster_port}"
      username          = local.master_username
      password          = local.master_password
      connection_string = local.connection_string
      secrets           = ["password", "connection_string"]
    }
  }
}