locals {
  spec = var.instance.spec

  # Use custom namespace if provided, otherwise fall back to default
  namespace = lookup(local.spec, "namespace", "") != "" ? lookup(local.spec, "namespace", "") : "kafka-system"

  # Helm chart configuration
  repository    = "https://strimzi.io/charts/"
  chart_name    = "strimzi-kafka-operator"
  chart_version = "0.48.0"

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

  # Build default values for Strimzi Operator with node pool support
  resources_spec = lookup(local.spec, "resources", {})

  default_values = {
    watchAnyNamespace = true
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
