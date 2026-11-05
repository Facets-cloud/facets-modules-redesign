locals {
  spec = var.instance.spec

  # Use custom namespace if provided, otherwise fall back to default
  namespace = lookup(local.spec, "namespace", "") != "" ? lookup(local.spec, "namespace", "") : "cassandra-system"

  # Helm chart configuration
  # Chart 0.30.1 ships k8ssandra-operator v1.32.x and bundles cass-operator.
  repository    = "https://helm.k8ssandra.io/stable"
  chart_name    = "k8ssandra-operator"
  chart_version = "0.30.1"

  # Whether to create the namespace
  create_namespace = true

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

  # Helm values from user (advanced overrides)
  helm_values = lookup(local.spec, "helm_values", {})

  resources_spec = lookup(local.spec, "resources", {})

  default_values = {
    # The chart default (clusterScoped=false) watches ONLY the operator's own
    # namespace. Cassandra instances are created in environment namespaces, so
    # the operator must be cluster-scoped.
    global = {
      clusterScoped = true
    }

    # Resource allocation for operator pods
    resources = {
      limits = {
        cpu    = lookup(local.resources_spec, "cpu_limit", "1")
        memory = lookup(local.resources_spec, "memory_limit", "1Gi")
      }
      requests = {
        cpu    = lookup(local.resources_spec, "cpu_request", "200m")
        memory = lookup(local.resources_spec, "memory_request", "256Mi")
      }
    }

    # Node pool configuration for operator pods
    nodeSelector = local.node_selector
    tolerations  = local.tolerations
  }

  # Merge default and custom values (helm_values override defaults)
  final_values = merge(local.default_values, local.helm_values)
}
