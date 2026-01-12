locals {
  # Advanced configuration from instance.advanced.externaldns (all optional)
  advanced = lookup(var.instance, "advanced", {})

  # Namespace and secret
  namespace   = "external-dns"
  secret_name = "${lower(var.instance_name)}-dns-secret"

  # Cluster details from GKE
  cluster_name = var.inputs.kubernetes_details.attributes.cluster_name

  # Project ID from GKE or cloud_account
  project_id = try(
    var.inputs.kubernetes_details.attributes.project_id,
    var.inputs.cloud_account.attributes.project_id,
    var.inputs.cloud_account.attributes.project,
    ""
  )

  # Region from GKE or cloud_account
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

  # Node scheduling configuration
  # For system components like external-dns, we want them to schedule on any available node
  # Only use node selectors if the nodepool has taints (requires pod affinity)
  # This ensures compatibility with:
  # - EKS Auto Mode (workload-driven labeling with operator: Exists)
  # - GKE Autopilot (managed node pools)
  # - Azure AKS with tainted nodepools (explicit scheduling required)

  # Get nodepool configuration
  # Handle cases where kubernetes_node_pool_details is null, attributes are null, or taints are null/empty
  nodepool_taints = try(
    var.inputs.kubernetes_node_pool_details.attributes.taints,
    []
  )
  # Taints can be null, empty list [], or a populated list
  # Only consider it "has taints" if it's a non-empty list
  has_nodepool_taints = try(length(local.nodepool_taints), 0) > 0

  # Only use node selector if nodepool has taints (meaning pods MUST schedule there)
  # Otherwise, let pods schedule on any node
  default_node_selector = local.has_nodepool_taints ? try(
    var.inputs.kubernetes_node_pool_details.attributes.node_selector,
    {}
  ) : {}

  # Build tolerations
  # Only add nodepool taints if they exist, otherwise just use environment defaults
  default_tolerations = local.has_nodepool_taints ? concat(
    try(var.environment.default_tolerations, []),
    local.nodepool_taints
  ) : try(var.environment.default_tolerations, [])

  # Allow override via advanced config if needed
  node_selector = lookup(local.externaldns, "node_selector", local.default_node_selector)
  tolerations   = lookup(local.externaldns, "tolerations", local.default_tolerations)

  # Service account name cleanup for GCP validation
  # GCP service account IDs must:
  # - Start with a lowercase letter
  # - Be 6-30 characters long
  # - Match regex ^[a-z]([-a-z0-9]*[a-z0-9])?$
  raw_sa_name        = module.service_account_name.name
  sa_name_trimmed    = trimsuffix(trimprefix(lower(local.raw_sa_name), "-"), "-")
  sa_name_prefixed   = length(regexall("^[a-z]", local.sa_name_trimmed)) > 0 ? local.sa_name_trimmed : "a${local.sa_name_trimmed}"
  service_account_id = substr(local.sa_name_prefixed, 0, min(30, length(local.sa_name_prefixed)))
}

