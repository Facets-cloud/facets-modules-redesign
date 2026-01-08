locals {
  # GCP provider configuration
  project_id = var.inputs.gcp_provider.attributes.project
  region     = var.inputs.network.attributes.region
  vpc_name   = var.inputs.network.attributes.vpc_name

  # Instance naming (GCP constraint: max 40 chars, lowercase alphanumeric and hyphens)
  name_sanitized = lower(replace("${var.instance_name}-${var.environment.unique_name}", "/[^a-zA-Z0-9-]/", "-"))
  instance_name  = substr(trim(local.name_sanitized, "-"), 0, 40)

  # Redis configuration from spec
  redis_version  = var.instance.spec.version_config.redis_version
  memory_size_gb = var.instance.spec.sizing.memory_size_gb
  tier           = var.instance.spec.sizing.tier

  # Restore configuration
  restore_from_backup = var.instance.spec.restore_config.restore_from_backup
  source_instance_id  = lookup(var.instance.spec.restore_config, "source_instance_id", null)

  # Security and network configuration
  enable_tls         = var.instance.spec.security.enable_tls
  authorized_network = var.inputs.network.attributes.vpc_self_link

  # Note: Port is dynamically assigned by GCP (6378 with TLS, 6379 without)
  # and is accessed via google_redis_instance.main.port
  
  # Location configuration
  location_id = "${local.region}-a"
}