locals {
  gcp_taint_effects = {
    "NO_SCHEDULE"        = "NoSchedule",
    "PREFER_NO_SCHEDULE" = "PreferNoSchedule"
    "NO_EXECUTE"         = "NoExecute"
  }
  output_taints = [for value in local.taints :
    {
      key      = value.key
      value    = value.value
      operator = "Equal"
      effect   = lookup(local.gcp_taint_effects, value.effect, value.effect)
    }
  ]
  output_interfaces = {}
  output_attributes = {
    topology_spread_key = "facets-cloud-fleet-${var.instance_name}"
    taints              = local.output_taints
    node_selector       = local.labels
  }
}
