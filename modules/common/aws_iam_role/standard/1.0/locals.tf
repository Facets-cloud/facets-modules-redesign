# Define your locals here

locals {
  name             = lower(var.instance_name)
  service_accounts = lookup(local.irsa, "service_accounts", {})
  namespace        = lookup(var.instance.metadata, "namespace", null) == null ? var.environment.namespace : var.instance.metadata.namespace
  spec             = lookup(var.instance, "spec", {})
  irsa             = lookup(local.spec, "irsa", {})
  oidc             = lookup(local.irsa, "oidc_providers", {})
  oidc_providers = merge({
    for k, v in local.oidc : k => {
      provider_arn               = v.arn
      namespace_service_accounts = [for x in local.service_accounts : "${lookup(x, "namespace", local.namespace)}:${x.name}"]
    }
    }, {
    facets = {
      provider_arn               = var.inputs.kubernetes_details.attributes.oidc_provider_arn
      namespace_service_accounts = [for x in local.service_accounts : "${lookup(x, "namespace", local.namespace)}:${x.name}"]
  } })
  policies          = lookup(local.spec, "policies", {})
  user_defined_tags = lookup(local.spec, "tags", {})
}
