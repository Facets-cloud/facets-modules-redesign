locals {
  output_attributes = {
    # Essential node pool identifiers
    node_pool_name = google_container_node_pool.node_pool.name
    node_pool_id   = google_container_node_pool.node_pool.id

    topology_spread_key = local.topology_spread_key

    # Kubernetes scheduling configurations
    taints        = lookup(local.spec, "taints", [])
    node_selector = local.labels

    # Service account for the node pool (if created)
    service_account = length(local.iam_roles) > 0 ? google_service_account.sa[0].email : null
  }

  output_interfaces = {}
}