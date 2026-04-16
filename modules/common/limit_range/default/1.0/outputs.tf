locals {
  output_attributes = {
    namespaces_applied = keys(local.namespace_limits)
    mode               = local.cluster_wide ? "cluster_wide" : "specific_namespaces"
    limit_type         = local.limit_type
  }

  output_interfaces = {}
}
