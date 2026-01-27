locals {
  # Advanced configuration from instance.advanced.externaldns (all optional)
  advanced = lookup(var.instance, "advanced", {})

  # Namespaces and secret
  namespace              = "external-dns"
  cert_manager_namespace = "cert-manager"
  secret_name            = "${lower(var.instance_name)}-dns-secret"

  # Cluster details
  cluster_name = var.inputs.kubernetes_details.attributes.cluster_name
  aws_region   = var.inputs.cloud_account.attributes.aws_region

  # Spec configuration
  spec = lookup(var.instance, "spec", {})

  # DNS configuration from spec
  hosted_zone_id = lookup(local.spec, "hosted_zone_id", "*")
  zone_type      = lookup(local.spec, "zone_type", "public")

  # DNS configuration
  # Can be provided via instance.advanced.externaldns.domain_filters (optional).
  # If not set, the chart will manage all zones it has access to.
  externaldns    = lookup(local.advanced, "externaldns", {})
  domain_filters = lookup(local.externaldns, "domain_filters", [])

  # Helm configuration
  helm_version              = lookup(local.externaldns, "version", "1.14.5")
  cleanup_on_fail           = lookup(local.externaldns, "cleanup_on_fail", true)
  wait                      = lookup(local.externaldns, "wait", false)
  atomic                    = lookup(local.externaldns, "atomic", false)
  timeout                   = lookup(local.externaldns, "timeout", 300)
  recreate_pods             = lookup(local.externaldns, "recreate_pods", false)
  user_supplied_helm_values = lookup(local.externaldns, "values", {})

  # Chart source configuration (configurable with fallback)
  # Default to official Kubernetes SIGs external-dns Helm chart
  chart_path       = lookup(local.externaldns, "chart_path", "")
  use_local_chart  = local.chart_path != ""
  chart_source     = local.use_local_chart ? local.chart_path : "external-dns"
  chart_repository = lookup(local.externaldns, "chart_repository", "https://kubernetes-sigs.github.io/external-dns")

  # Image configuration (configurable with fallback)
  # Default to official external-dns image from registry.k8s.io
  image_registry   = lookup(local.externaldns, "image_registry", "registry.k8s.io")
  image_repository = lookup(local.externaldns, "image_repository", "external-dns/external-dns")
  image_tag        = lookup(local.externaldns, "image_tag", "")

  # Priority class configuration
  # Allow override via advanced config, default to "facets-critical"
  # Users can set advanced.externaldns.priority_class_name to use a different priority class
  priority_class_name = lookup(local.externaldns, "priority_class_name", "facets-critical")

  # Node scheduling configuration
  # For system components like external-dns, we want them to schedule on any available node
  # Only use node selectors if the nodepool has taints (requires pod affinity)
  # This ensures compatibility with:
  # - EKS Auto Mode (workload-driven labeling with operator: Exists)
  # - GKE Autopilot (managed node pools)
  # - Azure AKS with tainted nodepools (explicit scheduling required)

  # Get nodepool configuration
  nodepool_taints = try(
    var.inputs.kubernetes_node_pool_details.attributes.taints,
    null
  )
  has_nodepool_taints = local.nodepool_taints != null && can(tolist(local.nodepool_taints)) && length(local.nodepool_taints) > 0

  # Only use node selector if nodepool has taints (meaning pods MUST schedule there)
  # Otherwise, let pods schedule on any node
  default_node_selector = local.has_nodepool_taints ? try(
    var.inputs.kubernetes_node_pool_details.attributes.node_selector,
    {}
  ) : {}

  # Build tolerations
  default_tolerations = local.has_nodepool_taints ? concat(
    try(var.environment.default_tolerations, []),
    tolist(local.nodepool_taints)
  ) : try(var.environment.default_tolerations, [])

  # Allow override via advanced config if needed
  node_selector = lookup(local.externaldns, "node_selector", local.default_node_selector)
  tolerations   = lookup(local.externaldns, "tolerations", local.default_tolerations)
}

