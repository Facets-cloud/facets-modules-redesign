# Define your locals here
locals {
  tenant_provider           = lower(local.cc_tenant_provider != "" ? local.cc_tenant_provider : "aws")
  spec                      = lookup(var.instance, "spec", {})
  user_supplied_helm_values = try(local.spec.cert_manager.values, try(var.instance.advanced.cert_manager.values, {}))
  cert_manager              = lookup(local.spec, "cert_manager", try(var.instance.advanced.cert_manager, {}))
  cert_mgr_namespace        = "cert-manager"
  advanced                  = lookup(lookup(var.instance, "advanced", {}), "cert_manager", {})

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

  # GTS and ACME configuration
  use_gts         = lookup(local.spec, "use_gts", false)
  gts_private_key = lookup(local.spec, "gts_private_key", "")
  acme_email      = lookup(local.spec, "acme_email", "") != "" ? lookup(local.spec, "acme_email", "") : null
}
