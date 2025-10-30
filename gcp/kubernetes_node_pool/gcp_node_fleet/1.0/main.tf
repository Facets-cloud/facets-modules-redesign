module "gke-node-fleet" {
  for_each = local.node_pools
  source   = "./gke_node_pool"
  instance = {
    metadata = {
      name = each.key
    }
    spec = {
      instance_type  = lookup(each.value, "instance_type", null)
      disk_size      = lookup(each.value, "disk_size", null)
      disk_type      = lookup(each.value, "disk_type", null)
      min_node_count = lookup(each.value, "min_node_count", null)
      max_node_count = lookup(each.value, "max_node_count", null)
      taints         = local.processed_taints
      is_public      = lookup(each.value, "is_public", false)
      labels = merge(local.labels, {
        "facets-cloud-fleet-${var.instance_name}" = each.key
      })
      iam = lookup(each.value, "iam", {})
    }
    advanced = {
      gke = merge({
        node_locations = lookup(each.value, "azs", lookup(var.inputs.network_details.attributes.legacy_outputs.vpc_details, "azs", lookup(var.cluster, "azs", null)))
        node_config = {
          spot = lookup(each.value, "type", null) == "spot" ? true : false
        }
        },
      lookup(local.gke_advanced, each.key, {}))
    }
  }
  instance_name = each.key
  environment   = var.environment
  baseinfra     = var.inputs.kubernetes_details.attributes.legacy_outputs
  cc_metadata   = var.cc_metadata
  cluster       = var.cluster
  inputs       = var.inputs
}
