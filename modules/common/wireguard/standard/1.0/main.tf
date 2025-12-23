locals {
  spec               = lookup(var.instance, "spec", {})
  namespace          = lookup(local.spec, "namespace", "") != "" ? lookup(local.spec, "namespace", "") : var.environment.namespace
  create_namespace   = local.namespace != "" ? true : false
  operator_resources = lookup(local.spec, "operator_resources", {})
  user_values        = lookup(local.spec, "values", {})

  # Operator resource requests and limits
  requests       = lookup(local.operator_resources, "requests", {})
  limits         = lookup(local.operator_resources, "limits", {})
  cpu_request    = lookup(local.requests, "cpu", "100m")
  memory_request = lookup(local.requests, "memory", "128Mi")
  cpu_limit      = lookup(local.limits, "cpu", "200m")
  memory_limit   = lookup(local.limits, "memory", "256Mi")

  # Get node pool details from input
  node_pool_input  = lookup(var.inputs, "node_pool", {})
  node_pool_attrs  = lookup(local.node_pool_input, "attributes", {})
  node_selector    = lookup(local.node_pool_attrs, "node_selector", {})
  node_pool_taints = lookup(local.node_pool_attrs, "taints", [])

  # Helm chart configuration
  version    = "0.2.0" # Fixed chart version as per module design
  wait       = true
  atomic     = true
  timeout    = 600

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

resource "helm_release" "wireguard_operator" {
  name             = var.instance_name
  repository       = "https://nccloud.github.io/charts"
  chart            = "wireguard-operator"
  version          = local.version
  namespace        = local.namespace
  create_namespace = local.create_namespace
  wait             = local.wait
  atomic           = local.atomic
  timeout          = local.timeout

  values = [
    yamlencode({
      # ---------------------------
      # Naming (prevents 63-char errors)
      # ---------------------------
      fullnameOverride = "wireguard-operator"

      # ---------------------------
      # Resources for controller pod
      # ---------------------------
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

      # ---------------------------
      # Scheduling
      # ---------------------------
      nodeSelector = local.node_selector
      tolerations  = local.tolerations
    }),

    # Advanced user overrides (optional)
    yamlencode(local.user_values)
  ]
}
