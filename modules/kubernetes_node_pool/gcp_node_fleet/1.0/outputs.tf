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

    # Node fleet specific attributes
    node_fleet_details = {
      node_pools = {
        for k, v in module.gke-node-fleet : k => {
          node_pool_name  = v.attributes.node_pool_name
          node_pool_id    = v.attributes.node_pool_id
          service_account = v.attributes.service_account
        }
      }
      fleet_name       = var.instance_name
      total_node_pools = length(local.node_pools)
    }
  }
}
