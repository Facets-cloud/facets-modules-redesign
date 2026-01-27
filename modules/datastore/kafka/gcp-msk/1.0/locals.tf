# Local variables for main.tf configuration only
# Output locals are handled in outputs.tf by the Facets framework

locals {
  # Import detection
  import_enabled    = lookup(var.instance.spec, "imports", null) != null ? lookup(var.instance.spec.imports, "import_existing", false) : false
  is_cluster_import = local.import_enabled && lookup(var.instance.spec.imports, "cluster_id", null) != null

  cluster_name = "${var.instance_name}-${var.environment.unique_name}"

  # Kafka configuration
  kafka_version = var.instance.spec.version_config.kafka_version
  vcpu_count    = var.instance.spec.sizing.vcpu_count
  memory_bytes  = var.instance.spec.sizing.memory_gb * 1024 * 1024 * 1024
  disk_size_gb  = var.instance.spec.sizing.disk_size_gb

  # Region and project from inputs
  project_id = var.inputs.gcp_cloud_account.attributes.project_id
  region     = var.inputs.gcp_cloud_account.attributes.region

  # Common labels
  common_labels = merge(
    var.environment.cloud_tags,
    {
      name        = local.cluster_name
      environment = var.environment.name
      module      = "kafka-gcp-msk"
    }
  )
}
