locals {
  namespace                  = lookup(lookup(var.instance, "metadata", {}), "namespace", "facets")
  spec                       = lookup(var.instance, "spec", {})
  image_pull_secret_injector = lookup(local.spec, "image_pull_secret_injector", {})
  user_supplied_helm_values  = lookup(local.spec, "values", {})
  size                       = lookup(local.spec, "size", {})
  cpu_limit                  = lookup(local.size, "cpu_limit", "200m")
  memory_limit               = lookup(local.size, "memory_limit", "1000Mi")
  dockerhub_secret_objects   = lookup(lookup(var.inputs.artifactories, "attributes", {}), "registry_secret_objects", {})
  secret_list = join(",", [
    for k, v in local.dockerhub_secret_objects : v[0].name
  ])
  # Nodepool configuration from inputs
  nodepool_attributes = lookup(lookup(var.inputs, "kubernetes_node_pool_details", {}), "attributes", {})
  tolerations         = lookup(local.nodepool_attributes, "taints", [])
  node_selector       = lookup(local.nodepool_attributes, "node_selector", {})
}
