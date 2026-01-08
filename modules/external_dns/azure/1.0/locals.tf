locals {
  spec     = lookup(var.instance, "spec", {})
  advanced = lookup(var.instance, "advanced", {})

  # Namespace and secret
  namespace   = "external-dns"
  secret_name = "${lower(var.instance_name)}-dns-secret"

  # Azure account details (from cloud_account module)
  subscription_id = var.inputs.cloud_account.attributes.subscription_id
  tenant_id       = var.inputs.cloud_account.attributes.tenant_id
  client_id       = var.inputs.cloud_account.attributes.client_id

  # Resource group comes from kubernetes_details (AKS → network module)
  resource_group_name = var.inputs.kubernetes_details.attributes.resource_group_name

  # Region comes from cluster_location (AKS region) or network_details
  region = try(
    var.inputs.kubernetes_details.attributes.cluster_location,
    var.inputs.kubernetes_details.attributes.network_details.region,
    ""
  )

  # DNS configuration
  domain_filters = lookup(local.spec, "domain_filters", [])

  # Helm configuration
  externaldns               = lookup(local.advanced, "externaldns", {})
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

