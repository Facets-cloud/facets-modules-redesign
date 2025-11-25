locals {
  spec = var.instance.spec

  # Use custom namespace if provided, otherwise fall back to default
  namespace = var.instance.spec.namespace != "" ? var.instance.spec.namespace : "mongodb-system"

  # Helm chart configuration
  repository    = "https://mongodb.github.io/helm-charts"
  chart_name    = "mongodb-kubernetes"
  chart_version = "1.4.0"

  # Whether to create the namespace
  create_namespace = true

  # Get Kubernetes cluster details
  k8s_cluster_input = lookup(var.inputs, "kubernetes_cluster", {})
  k8s_cluster_attrs = lookup(local.k8s_cluster_input, "attributes", {})

  # Get node pool details from input
  node_pool_input  = lookup(var.inputs, "node_pool", {})
  node_pool_attrs  = lookup(local.node_pool_input, "attributes", {})
  node_selector    = lookup(local.node_pool_attrs, "node_selector", {})
  node_pool_taints = lookup(local.node_pool_attrs, "taints", {})

  # Convert taints from {key: "key", value: "value", effect: "effect"} to tolerations format
  tolerations = [
    for taint_name, taint_config in local.node_pool_taints : {
      key      = taint_config.key
      operator = "Equal"
      value    = taint_config.value
      effect   = taint_config.effect
    }
  ]

  # Helm values from user (advanced overrides)
  helm_values = lookup(local.spec, "helm_values", {})

  # Build default values for MongoDB Operator with node pool support
  default_values = {
    # Resource allocation for operator pods
    operator = {
      resources = {
        limits = {
          cpu    = var.instance.spec.resources.cpu_limit
          memory = var.instance.spec.resources.memory_limit
        }
        requests = {
          cpu    = var.instance.spec.resources.cpu_request
          memory = var.instance.spec.resources.memory_request
        }
      }

      # Node pool configuration for operator pods
      nodeSelector = local.node_selector
      tolerations  = local.tolerations
    }
  }

  # Merge default and custom values (helm_values override defaults)
  final_values = merge(local.default_values, local.helm_values)
}
