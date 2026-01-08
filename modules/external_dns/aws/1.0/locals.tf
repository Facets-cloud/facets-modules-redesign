locals {
  spec    = lookup(var.instance, "spec", {})
  advanced = lookup(var.instance, "advanced", {})

  # DNS configuration
  hosted_zone_id = lookup(local.spec, "hosted_zone_id", "*")
  domain_filters = lookup(local.spec, "domain_filters", [])
  zone_type      = lookup(local.spec, "zone_type", "public")

  # Cluster details
  cluster_name   = var.inputs.kubernetes_details.attributes.cluster_name
  aws_region     = var.inputs.cloud_account.attributes.aws_region

  # Namespace and secret
  namespace      = "external-dns"
  secret_name    = "${lower(var.instance_name)}-dns-secret"

  # Helm configuration
  externaldns               = lookup(local.advanced, "externaldns", {})
  helm_version              = lookup(local.externaldns, "version", "6.28.5")
  cleanup_on_fail           = lookup(local.externaldns, "cleanup_on_fail", true)
  wait                      = lookup(local.externaldns, "wait", false)
  atomic                    = lookup(local.externaldns, "atomic", false)
  timeout                   = lookup(local.externaldns, "timeout", 300)
  recreate_pods             = lookup(local.externaldns, "recreate_pods", false)
  user_supplied_helm_values = lookup(local.externaldns, "values", {})

  # Chart source configuration (configurable with fallback)
  chart_path       = lookup(local.externaldns, "chart_path", "")
  use_local_chart  = local.chart_path != ""
  chart_source     = local.use_local_chart ? local.chart_path : "external-dns"
  chart_repository = lookup(local.externaldns, "chart_repository", "oci://registry-1.docker.io/bitnamicharts")

  # Image configuration (configurable with fallback)
  image_registry   = lookup(local.externaldns, "image_registry", "docker.io")
  image_repository = lookup(local.externaldns, "image_repository", "bitnami/external-dns")
  image_tag        = lookup(local.externaldns, "image_tag", "")

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

