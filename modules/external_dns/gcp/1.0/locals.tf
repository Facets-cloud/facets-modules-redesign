locals {
  spec     = lookup(var.instance, "spec", {})
  advanced = lookup(var.instance, "advanced", {})

  # DNS configuration
  domain_filters    = lookup(local.spec, "domain_filters", [])
  zone_visibility   = lookup(local.spec, "zone_visibility", "")
  batch_change_size = lookup(local.spec, "batch_change_size", 1000)

  # Namespace and secret
  namespace   = "external-dns"
  secret_name = "${lower(var.instance_name)}-dns-secret"

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

  # Helm configuration
  externaldns               = lookup(local.advanced, "externaldns", {})
  helm_version              = lookup(local.externaldns, "version", "6.28.5")
  cleanup_on_fail           = lookup(local.externaldns, "cleanup_on_fail", true)
  wait                      = lookup(local.externaldns, "wait", false)
  atomic                    = lookup(local.externaldns, "atomic", false)
  timeout                   = lookup(local.externaldns, "timeout", 300)
  recreate_pods             = lookup(local.externaldns, "recreate_pods", false)
  user_supplied_helm_values = lookup(local.externaldns, "values", {})

  # Node scheduling
  node_selector = try(
    var.inputs.kubernetes_node_pool_details.attributes.node_selector,
    {}
  )
  tolerations = concat(
    try(var.environment.default_tolerations, []),
    try(var.inputs.kubernetes_node_pool_details.attributes.taints, [])
  )
}

