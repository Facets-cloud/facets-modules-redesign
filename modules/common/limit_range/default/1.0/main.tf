locals {
  spec = lookup(var.instance, "spec", {})

  cluster_wide       = lookup(local.spec, "cluster_wide", true)
  exclude_namespaces = toset(lookup(local.spec, "exclude_namespaces", ["kube-node-lease", "kube-public"]))
  target_namespaces  = toset(lookup(local.spec, "target_namespaces", []))

  limits              = lookup(local.spec, "limits", {})
  limit_type          = lookup(local.limits, "type", "Container")
  base_default        = lookup(local.limits, "default", {})
  base_default_req    = lookup(local.limits, "default_request", {})
  base_min            = lookup(local.limits, "min", {})
  base_max            = lookup(local.limits, "max", {})
  base_ratio          = lookup(local.limits, "max_limit_request_ratio", {})
  namespace_overrides = lookup(local.spec, "namespace_overrides", {})

  # Resolve target namespace set based on mode
  all_namespaces      = local.cluster_wide ? toset(data.kubernetes_all_namespaces.all[0].namespaces) : toset([])
  filtered_all        = setsubtract(local.all_namespaces, local.exclude_namespaces)
  resolved_namespaces = local.cluster_wide ? local.filtered_all : local.target_namespaces

  # Build per-namespace limit specs with overrides merged on top of base
  namespace_limits = {
    for ns in local.resolved_namespaces : ns => {
      default                 = length(lookup(lookup(local.namespace_overrides, ns, {}), "default", {})) > 0 ? merge(local.base_default, lookup(local.namespace_overrides[ns], "default", {})) : local.base_default
      default_request         = length(lookup(lookup(local.namespace_overrides, ns, {}), "default_request", {})) > 0 ? merge(local.base_default_req, lookup(local.namespace_overrides[ns], "default_request", {})) : local.base_default_req
      min                     = length(lookup(lookup(local.namespace_overrides, ns, {}), "min", {})) > 0 ? merge(local.base_min, lookup(local.namespace_overrides[ns], "min", {})) : local.base_min
      max                     = length(lookup(lookup(local.namespace_overrides, ns, {}), "max", {})) > 0 ? merge(local.base_max, lookup(local.namespace_overrides[ns], "max", {})) : local.base_max
      max_limit_request_ratio = length(lookup(lookup(local.namespace_overrides, ns, {}), "max_limit_request_ratio", {})) > 0 ? merge(local.base_ratio, lookup(local.namespace_overrides[ns], "max_limit_request_ratio", {})) : local.base_ratio
    }
  }
}

data "kubernetes_all_namespaces" "all" {
  count = local.cluster_wide ? 1 : 0
}

resource "kubernetes_limit_range_v1" "this" {
  for_each = local.namespace_limits

  metadata {
    name      = var.instance_name
    namespace = each.key
    labels = {
      "app.kubernetes.io/managed-by" = "facets"
      "facets.cloud/module"          = "limit-range"
    }
  }

  spec {
    limit {
      type                    = local.limit_type
      default                 = length(each.value.default) > 0 ? each.value.default : null
      default_request         = length(each.value.default_request) > 0 ? each.value.default_request : null
      min                     = length(each.value.min) > 0 ? each.value.min : null
      max                     = length(each.value.max) > 0 ? each.value.max : null
      max_limit_request_ratio = length(each.value.max_limit_request_ratio) > 0 ? each.value.max_limit_request_ratio : null
    }
  }
}
