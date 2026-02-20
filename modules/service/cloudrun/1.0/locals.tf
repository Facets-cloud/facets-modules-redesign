locals {
  service_name = module.name.name
  location     = var.inputs.gcp_provider.attributes.region
  project_id   = var.inputs.gcp_provider.attributes.project_id

  # Merge environment cloud tags with instance labels
  all_labels = merge(
    var.environment.cloud_tags,
    lookup(var.instance.spec, "labels", {})
  )

  # VPC connector configuration - use vpc_connector_name from network attributes if available
  vpc_connector = (
    var.inputs.network != null &&
    lookup(var.instance.spec.vpc_access, "enabled", false)
  ) ? lookup(lookup(var.inputs.network, "attributes", {}), "vpc_connector_name", null) : null

  # Health check probes
  startup_probe_enabled  = lookup(var.instance.spec.health_checks.startup_probe, "enabled", false)
  liveness_probe_enabled = lookup(var.instance.spec.health_checks.liveness_probe, "enabled", false)

  # CPU idle - allow manual override or default based on min_instances
  cpu_idle = lookup(var.instance.spec.resources, "cpu_idle", lookup(var.instance.spec.scaling, "min_instances", 0) == 0)

  # Ingress configuration - transform to Cloud Run format
  ingress_setting = lookup(var.instance.spec, "ingress", "all")
  ingress_value   = local.ingress_setting != "" ? "INGRESS_TRAFFIC_${upper(replace(local.ingress_setting, "-", "_"))}" : "INGRESS_TRAFFIC_ALL"

  # Deletion protection - configurable with secure default
  deletion_protection = lookup(var.instance.spec, "deletion_protection", true)
}
