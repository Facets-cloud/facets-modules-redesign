# Define your locals here
locals {
  tenant_provider           = lower(local.cc_tenant_provider != "" ? local.cc_tenant_provider : "aws")
  spec                      = lookup(var.instance, "spec", {})
  user_supplied_helm_values = try(local.spec.cert_manager.values, {})
  cert_manager              = lookup(local.spec, "cert_manager", {})
  cert_mgr_namespace        = "cert-manager"

  http_validations = {
    staging-http01 = {
      name = "letsencrypt-staging-http01"
      url  = "https://acme-staging-v02.api.letsencrypt.org/directory"
      solvers = [
        {
          http01 = {
            ingress = {
              podTemplate = {
                spec = {
                  nodeSelector = local.nodepool_labels
                  tolerations  = local.nodepool_tolerations
                }
              }
            }
          }
        },
      ]
    }
    production-http01 = {
      name = "letsencrypt-prod-http01"
      url  = "https://acme-v02.api.letsencrypt.org/directory"
      solvers = [
        {
          http01 = {
            ingress = {
              podTemplate = {
                spec = {
                  nodeSelector = local.nodepool_labels
                  tolerations  = local.nodepool_tolerations
                }
              }
            }
          }
        },
      ]
    }
  }
  environments = local.http_validations

  # Nodepool configuration from inputs
  nodepool_config      = lookup(var.inputs, "kubernetes_node_pool_details", null)
  nodepool_tolerations = lookup(local.nodepool_config, "taints", [])
  nodepool_labels      = lookup(local.nodepool_config, "node_selector", {})

  # Use only nodepool configuration (no fallback to default tolerations)
  tolerations  = local.nodepool_tolerations
  nodeSelector = local.nodepool_labels

  # ACME configuration
  acme_email = lookup(local.spec, "acme_email", "") != "" ? lookup(local.spec, "acme_email", "") : null

  # Prometheus configuration - enabled only if helm_release_id is provided
  prometheus_enabled = try(var.inputs.prometheus_details.attributes.helm_release_id, "") != ""

  # Gateway API support - enabled when gateway_api_crd_details input is provided
  enable_gateway_api = lookup(var.inputs, "gateway_api_crd_details", null) != null
}
