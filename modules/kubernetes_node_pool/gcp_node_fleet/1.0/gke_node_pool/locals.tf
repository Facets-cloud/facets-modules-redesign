locals {
  spec = lookup(var.instance, "spec", {})

  topology_spread_key = "facets-cloud-np-${var.instance_name}"

  # Node pool configuration from spec
  labels = merge(lookup(local.spec, "labels", {}), {
    "${local.topology_spread_key}" = var.instance_name
  })
  spot                 = lookup(local.spec, "spot", false)
  iam_roles            = lookup(lookup(local.spec, "iam", {}), "roles", {})
  autoscaling_per_zone = lookup(local.spec, "autoscaling_per_zone", false)

  # Management settings from spec
  auto_repair = lookup(lookup(local.spec, "management", {}), "auto_repair", true)
  # auto_upgrade follows cluster auto_upgrade setting - access via attributes
  kubernetes_attributes = lookup(lookup(var.inputs, "kubernetes_details", {}), "attributes", {})
  auto_upgrade          = lookup(local.kubernetes_attributes, "auto_upgrade", "false")

  # Network configuration - access via lookup for optional attributes
  network_attributes = lookup(lookup(var.inputs, "network_details", {}), "attributes", {})
  pod_ip_range_name  = lookup(local.network_attributes, "gke_pods_range_name", "")

  # Node configuration from spec
  max_pods_per_node = lookup(local.spec, "max_pods_per_node", null)

  # Zones from network module and single-AZ logic
  single_az     = lookup(local.spec, "single_az", false)
  network_zones = lookup(local.network_attributes, "zones", [])
  # If single_az is true, use first zone only; otherwise use all network zones
  node_locations = local.single_az ? (length(local.network_zones) > 0 ? [local.network_zones[0]] : null) : (length(local.network_zones) > 0 ? local.network_zones : null)
  gcp_taints_effects = {
    "NoSchedule" : "NO_SCHEDULE",
    "PreferNoSchedule" : "PREFER_NO_SCHEDULE",
    "NoExecute" : "NO_EXECUTE"
  }
  taints = [for value in var.instance.spec.taints : merge(value, {
    effect = lookup(local.gcp_taints_effects, value.effect, "NoSchedule")
  })]
}