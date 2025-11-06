# locals.tf - Local computations

locals {
  # Check if this is an import operation
  is_import = var.instance.spec.imports.cluster_identifier != null && var.instance.spec.imports.cluster_identifier != ""


  # Security group ID - use imported one if importing, otherwise use created one
  security_group_id = local.is_import ? var.instance.spec.imports.security_group_id : aws_security_group.documentdb[0].id

  # Extract cluster information
  cluster_endpoint = aws_docdb_cluster.main.endpoint
  cluster_port     = aws_docdb_cluster.main.port
  master_username  = aws_docdb_cluster.main.master_username

  # Handle password logic:
  # - restore_from_snapshot → use restore password
  # - import → use imported master password
  # - new cluster → use generated random password
  master_password = (var.instance.spec.restore_config.restore_from_snapshot ? var.instance.spec.restore_config.master_password : local.is_import ? var.instance.spec.imports.master_password : random_password.master[0].result)

  # Connection string for MongoDB
  connection_string = "mongodb://${local.master_username}:${local.master_password}@${local.cluster_endpoint}:${local.cluster_port}/?tls=true&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
}