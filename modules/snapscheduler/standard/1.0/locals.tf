locals {
  namespace                 = lookup(var.instance.spec, "namespace", "default")
  user_supplied_helm_values = lookup(var.instance.spec, "helm_values", {})

  # Resource defaults
  cpu_request    = lookup(lookup(var.instance.spec, "resources", {}), "cpu_request", "10m")
  cpu_limit      = lookup(lookup(var.instance.spec, "resources", {}), "cpu_limit", "1")
  memory_request = lookup(lookup(var.instance.spec, "resources", {}), "memory_request", "100Mi")
  memory_limit   = lookup(lookup(var.instance.spec, "resources", {}), "memory_limit", "1Gi")

  # Node pool configuration
  node_pool_input  = lookup(var.inputs, "node_pool", {})
  node_pool_attrs  = lookup(local.node_pool_input, "attributes", {})
  node_selector    = lookup(local.node_pool_attrs, "node_selector", {})
  node_pool_taints = lookup(local.node_pool_attrs, "taints", [])

  # Convert taints to tolerations format
  tolerations = [
    for taint in local.node_pool_taints : {
      key      = taint.key
      operator = "Equal"
      value    = taint.value
      effect   = taint.effect
    }
  ]

  # Prometheus integration
  prometheus_release_id = lookup(lookup(lookup(var.inputs, "prometheus_details", {}), "attributes", {}), "helm_release_id", "")

  # Build default helm values
  default_values = {
    prometheus_id = local.prometheus_release_id
    rbacProxy = {
      image = {
        tag = "v0.19.0"
      }
    }
    image = {
      repository  = "facetscloud/snapscheduler"
      tagOverride = 9
      pullPolicy  = "IfNotPresent"
    }
    resources = {
      limits = {
        cpu    = local.cpu_limit
        memory = local.memory_limit
      }
      requests = {
        cpu    = local.cpu_request
        memory = local.memory_request
      }
    }
    nodeSelector = local.node_selector
    tolerations  = local.tolerations
  }

  # Merge default and user-supplied values
  final_values = merge(local.default_values, local.user_supplied_helm_values)
}
