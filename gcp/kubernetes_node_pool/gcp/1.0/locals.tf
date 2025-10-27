locals {
  spec = lookup(var.instance, "spec", {})

  # Node pool configuration from spec
  labels               = lookup(local.spec, "labels", {})
  spot                 = lookup(local.spec, "spot", false)
  iam_roles            = lookup(lookup(local.spec, "iam", {}), "roles", {})
  autoscaling_per_zone = lookup(local.spec, "autoscaling_per_zone", false)

  # Management settings from spec
  auto_repair = lookup(lookup(local.spec, "management", {}), "auto_repair", true)
  # auto_upgrade follows cluster auto_upgrade setting
  auto_upgrade = var.inputs.kubernetes_details.auto_upgrade

  # Network configuration
  pod_ip_range_name = lookup(var.inputs.network_details.attributes, "gke_pods_range_name", "")

  # Node configuration from spec
  max_pods_per_node = lookup(local.spec, "max_pods_per_node", null)

  # Zones from network module and single-AZ logic
  single_az     = lookup(local.spec, "single_az", false)
  network_zones = lookup(var.inputs.network_details.attributes, "zones", [])
  # If single_az is true, use first zone only; otherwise use all network zones
  node_locations = local.single_az ? (length(local.network_zones) > 0 ? [local.network_zones[0]] : null) : (length(local.network_zones) > 0 ? local.network_zones : null)
}