locals {
  # Spec extraction with lookup() defaults
  size          = lookup(var.instance.spec, "size", {})
  custom_values = lookup(var.instance.spec, "custom_values", {})
  chart_version = lookup(var.instance.spec, "chart_version", "2.9.4")

  # Resource sizing - same field for both limits and requests (matching skeleton behavior)
  # When user sets a value, it applies to both. Different fallback defaults per context.
  cpu_limit      = lookup(local.size, "cpu", "1")
  memory_limit   = lookup(local.size, "memory", "1000Mi")
  cpu_request    = lookup(local.size, "cpu", "100m")
  memory_request = lookup(local.size, "memory", "100m")

  # Prometheus details - optional input, extract helm_release_id if available
  prometheus_attributes = var.inputs.prometheus_details != null ? lookup(var.inputs.prometheus_details, "attributes", {}) : {}
  prometheus_release_id = lookup(local.prometheus_attributes, "helm_release_id", "")

  # Nodepool configuration from inputs
  nodepool_attributes  = lookup(var.inputs.kubernetes_node_pool_details, "attributes", {})
  nodepool_tolerations = lookup(local.nodepool_attributes, "taints", [])
  nodepool_labels      = lookup(local.nodepool_attributes, "node_selector", {})
  
  #kubernetes details inputs attributes 
  kubernetes_details = lookup(var.inputs, "kubernetes_details", {})
  kubernetes_attributes = lookup(local.kubernetes_details, "attributes", {})

  # Use nodepool configuration for tolerations and node selectors
  tolerations    = local.nodepool_tolerations
  node_selectors = local.nodepool_labels

}
