locals {
  output_attributes = {}
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
    secrets = ["writer", "reader", "cluster"]
  }
}