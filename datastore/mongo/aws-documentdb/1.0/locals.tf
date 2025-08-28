# locals.tf - Local computations

locals {
  # Extract cluster information
  cluster_endpoint = aws_docdb_cluster.main.endpoint
  cluster_port     = aws_docdb_cluster.main.port
  master_username  = aws_docdb_cluster.main.master_username
  master_password  = var.instance.spec.restore_config.restore_from_snapshot ? var.instance.spec.restore_config.master_password : random_password.master[0].result

  # Connection string for MongoDB
  connection_string = "mongodb://${local.master_username}:${local.master_password}@${local.cluster_endpoint}:${local.cluster_port}/?tls=true&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
}