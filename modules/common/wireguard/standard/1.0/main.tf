locals {
  spec             = lookup(var.instance, "spec", {})
  namespace        = lookup(local.spec, "namespace", var.environment.namespace)
  create_namespace = lookup(local.spec, "create_namespace", true)
  helm_config      = lookup(local.spec, "helm_config", {})
  resources        = lookup(local.spec, "resources", {})
  user_values      = lookup(local.spec, "values", {})

  # Resource requests and limits
  requests       = lookup(local.resources, "requests", {})
  limits         = lookup(local.resources, "limits", {})
  cpu_request    = lookup(local.requests, "cpu", "100m")
  memory_request = lookup(local.requests, "memory", "256Mi")
  cpu_limit      = lookup(local.limits, "cpu", "100m")
  memory_limit   = lookup(local.limits, "memory", "256Mi")

  # Get node pool details from input
  node_pool_input  = lookup(var.inputs, "node_pool", {})
  node_pool_attrs  = lookup(local.node_pool_input, "attributes", {})
  node_selector    = lookup(local.node_pool_attrs, "node_selector", {})
  node_pool_taints = lookup(local.node_pool_attrs, "taints", [])

  # Convert taints from {key, value, effect} to tolerations format
  tolerations = [
    for taint in local.node_pool_taints : {
      key      = taint.key
      operator = "Equal"
      value    = taint.value
      effect   = taint.effect
    }
  ]
}

resource "helm_release" "wireguard_release" {
  name             = var.instance_name
  repository       = "https://bryopsida.github.io/wireguard-chart"
  chart            = "wireguard"
  version          = lookup(local.helm_config, "version", "0.31.0")
  namespace        = local.namespace != "" ? local.namespace : var.environment.namespace
  create_namespace = local.create_namespace
  wait             = lookup(local.helm_config, "wait", true)
  atomic           = lookup(local.helm_config, "atomic", true)
  timeout          = lookup(local.helm_config, "timeout", 600)

  values = [
    yamlencode({
      resources = {
        requests = {
          cpu    = local.cpu_request
          memory = local.memory_request
        }
        limits = {
          cpu    = local.cpu_limit
          memory = local.memory_limit
        }
      }
      nodeSelector = local.node_selector
      tolerations  = local.tolerations
    }),
    # -----------------------------------
    # User-provided raw Helm overrides
    # -----------------------------------
    yamlencode(local.user_values)
  ]
}
