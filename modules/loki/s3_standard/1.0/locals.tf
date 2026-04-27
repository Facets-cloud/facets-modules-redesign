locals {
  # Naming
  sa_name   = "${var.environment.unique_name}-${lower(var.instance_name)}-loki"
  namespace = lookup(var.instance.spec, "namespace", "loki")

  # S3 details from input
  bucket_name = var.inputs.s3_details.attributes.bucket_name
  bucket_arn  = var.inputs.s3_details.attributes.bucket_arn
  aws_region  = var.inputs.cloud_account.attributes.aws_region

  # EKS OIDC for IRSA
  oidc_provider_arn = var.inputs.eks_details.attributes.oidc_provider_arn
  oidc_provider     = var.inputs.eks_details.attributes.oidc_provider

  # Spec extraction
  retention_period = lookup(var.instance.spec, "retention_period", "744h")
  query_timeout    = lookup(var.instance.spec, "query_timeout", 60)

  # Loki component sizing
  loki_size               = lookup(var.instance.spec, "loki_size", {})
  distributor             = lookup(local.loki_size, "distributor", {})
  distributor_requests    = lookup(local.distributor, "requests", {})
  distributor_limits      = lookup(local.distributor, "limits", {})
  ingester                = lookup(local.loki_size, "ingester", {})
  ingester_requests       = lookup(local.ingester, "requests", {})
  ingester_limits         = lookup(local.ingester, "limits", {})
  querier                 = lookup(local.loki_size, "querier", {})
  querier_requests        = lookup(local.querier, "requests", {})
  querier_limits          = lookup(local.querier, "limits", {})
  compactor               = lookup(local.loki_size, "compactor", {})
  compactor_requests      = lookup(local.compactor, "requests", {})
  compactor_limits        = lookup(local.compactor, "limits", {})
  query_frontend          = lookup(local.loki_size, "query_frontend", {})
  query_frontend_requests = lookup(local.query_frontend, "requests", {})
  query_frontend_limits   = lookup(local.query_frontend, "limits", {})

  # Promtail sizing
  promtail_size     = lookup(var.instance.spec, "promtail_size", {})
  promtail_requests = lookup(local.promtail_size, "requests", {})
  promtail_limits   = lookup(local.promtail_size, "limits", {})

  # Custom values
  loki_custom_values     = lookup(var.instance.spec, "loki_custom_values", {})
  promtail_custom_values = lookup(var.instance.spec, "promtail_custom_values", {})

  # Tags
  instance_tags = merge(
    var.environment.cloud_tags,
    {
      "facets:instance_name" = var.instance_name
      "facets:environment"   = var.environment.name
      "facets:component"     = "loki-s3"
    }
  )
}
