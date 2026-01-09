locals {
  # Advanced configuration from instance.advanced.externaldns (all optional)
  advanced = lookup(var.instance, "advanced", {})

  # Namespace and secret
  namespace   = "external-dns"
  secret_name = "${lower(var.instance_name)}-dns-secret"

  # Cluster details
  cluster_name = var.inputs.kubernetes_details.attributes.cluster_name

  # Project ID can come from kubernetes_details (GKE) or cloud_account
  project_id = try(
    var.inputs.kubernetes_details.attributes.project_id,
    var.inputs.cloud_account.attributes.project_id,
    var.inputs.cloud_account.attributes.project,
    ""
  )

  # Region can come from kubernetes_details (GKE) or cloud_account
  region = try(
    var.inputs.kubernetes_details.attributes.region,
    var.inputs.cloud_account.attributes.region,
    "us-central1"
  )

  # Spec configuration
  spec = lookup(var.instance, "spec", {})

  # DNS configuration from spec
  zone_visibility   = lookup(local.spec, "zone_visibility", "public")
  batch_change_size = lookup(local.spec, "batch_change_size", 1000)

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

  # Node scheduling
  node_selector = try(
    var.inputs.kubernetes_node_pool_details.attributes.node_selector,
    {}
  )
  # Handle taints: convert null/object to empty list, ensure it's always a list
  # taints can come as: null, {}, [], or list of objects with {key, value, effect}
  # Check if taints exists and is a list, otherwise return empty list
  nodepool_taints = try(
    var.inputs.kubernetes_node_pool_details.attributes.taints,
    null
  )
  tolerations = concat(
    try(var.environment.default_tolerations, []),
    local.nodepool_taints != null && can(tolist(local.nodepool_taints)) ? tolist(local.nodepool_taints) : []
  )
}

