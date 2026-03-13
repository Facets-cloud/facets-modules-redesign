locals {
  project_id = var.inputs.gcp_provider.attributes.project_id
  region     = var.inputs.gcp_provider.attributes.region

  # Zone: use spec override or default to region + "-a"
  zone = coalesce(
    lookup(var.instance.spec.runtime.size, "zone", null),
    "${local.region}-a"
  )

  # Merge environment cloud tags with instance labels
  all_labels = merge(
    var.environment.cloud_tags,
    lookup(var.instance.spec, "labels", {})
  )

  # Startup script passed via runtime.startup_script
  startup_script = lookup(var.instance.spec.runtime, "startup_script", "")

  # Instance metadata: env key-value pairs + startup-script (if provided)
  instance_metadata = merge(
    lookup(var.instance.spec, "env", {}),
    local.startup_script != "" ? { "startup-script" = local.startup_script } : {}
  )

  # Subnetwork self_link from network input (optional)
  subnetwork = try(var.inputs.network.attributes.private_subnet_id, null)

  # Whether to attach an ephemeral external IP to each instance
  # try() handles the case where spec.network is not provided in the resource config
  assign_external_ip = try(var.instance.spec.network.assign_external_ip, true)

  # Network tags for firewall rule targeting
  network_tags = try(var.instance.spec.network.network_tags, [])
}
