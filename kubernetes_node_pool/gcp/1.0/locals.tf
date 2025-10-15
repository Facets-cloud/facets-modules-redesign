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
  auto_upgrade = var.inputs.kubernetes_details.attributes.auto_upgrade

  # Network configuration
  pod_ip_range_name = lookup(var.inputs.network_details.attributes, "gke_pods_range_name", "")

  # Node configuration from spec
  max_pods_per_node = lookup(local.spec, "max_pods_per_node", null)
  node_locations    = lookup(local.spec, "node_locations", null)
}