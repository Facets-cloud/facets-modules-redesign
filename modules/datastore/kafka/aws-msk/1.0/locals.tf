# Local variables for main.tf configuration only
# Output locals are handled in outputs.tf by the Facets framework

locals {
  cluster_name = "${var.instance_name}-${var.environment.unique_name}"

  # Import flag
  import_enabled = lookup(var.instance.spec, "imports", null) != null ? lookup(var.instance.spec.imports, "import_existing", false) : false

  # Check if this is an import operation
  is_import = local.import_enabled && var.instance.spec.imports.cluster_arn != null && var.instance.spec.imports.cluster_arn != ""

  # Security group ID - use imported one if importing, otherwise use created one
  security_group_id = local.is_import ? var.instance.spec.imports.security_group_id : aws_security_group.msk_cluster[0].id

  # Select client subnets based on user preference
  client_subnet_ids = slice(var.inputs.vpc_details.attributes.private_subnet_ids, 0, var.instance.spec.sizing.client_subnets_count)

  # Kafka configuration
  kafka_version = var.instance.spec.version_config.kafka_version
  instance_type = var.instance.spec.version_config.instance_type

  # Common tags
  common_tags = merge(
    var.environment.cloud_tags,
    {
      Name        = local.cluster_name
      Environment = var.environment.name
      Module      = "kafka-msk"
    }
  )
}