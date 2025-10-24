# Local values for GCP Redis Memorystore configuration

locals {
  # Basic configuration
  project_id = var.inputs.gcp_provider.attributes.project
  region     = var.inputs.network != null ? var.inputs.network.attributes.region : "us-central1"
  vpc_name   = var.inputs.network != null ? var.inputs.network.attributes.vpc_name : "default"

  # Instance naming - ensuring GCP naming compliance (40 chars max for Redis)
  instance_name = substr(
    replace(
      replace(
        "${var.instance_name}-${var.environment.unique_name}",
        "/[^a-z0-9-]/",
        "-"
      ),
      "/^-+|-+$/",
      ""
    ),
    0, 40
  )

  # Redis configuration
  redis_version  = var.instance.spec.version_config.redis_version
  memory_size_gb = var.instance.spec.sizing.memory_size_gb
  tier           = var.instance.spec.sizing.tier

  # Restore configuration
  restore_from_backup = var.instance.spec.restore_config.restore_from_backup
  source_instance_id  = lookup(var.instance.spec.restore_config, "source_instance_id", null)

  # Network configuration - use existing private services connection from network module if available
  # Fall back to default VPC for testing when network module is not available
  authorized_network = var.inputs.network != null ? var.inputs.network.attributes.vpc_self_link : null

  # Redis port (standard)
  redis_port = 6379

  # Location - use first zone from the region
  location_id = "${local.region}-a"
}