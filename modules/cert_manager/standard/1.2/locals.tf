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
  # When false, this module renders NO ClusterIssuers — for estates where the issuers already exist
  # live and are owned by another resource (zero-change adoption). Defaults to true (existing behaviour).
  manage_cluster_issuers = lookup(local.spec, "manage_cluster_issuers", true)
  # ADOPTION: an imported estate already has its ClusterIssuers, each with its own name, ACME
  # email and account-key Secret - none of which follow this module's generated
  # "letsencrypt-<key>-account-key" pattern (live carries e.g. letsencrypt-production-account-key
  # and a Google Trust Services issuer with a different CA and email entirely). `cluster_issuers`
  # lets those be reproduced exactly. Absent it the built-in default stands, so a greenfield
  # deploy is unchanged.
  user_cluster_issuers = lookup(local.spec, "cluster_issuers", {})

  # Composed with merge() and `if` guards, NOT a ternary. A `? :` compares the two maps as OBJECT
  # types, and an object's KEYS are part of its type - so "letsencrypt-prod vs staging-http01"
  # is itself a type mismatch, no matter how carefully the VALUES are normalised (rules.md #18o).
  use_spec_issuers = length(local.user_cluster_issuers) > 0
  builtin_issuers = {
    for k, v in local.http_validations : k => {
      name       = v.name
      server     = v.url
      email      = local.acme_email
      key_ref    = "letsencrypt-${k}-account-key"
      solvers    = v.solvers
      acme_extra = {}
    }
  }
  spec_issuers = {
    for k, v in local.user_cluster_issuers : k => {
      name    = lookup(v, "name", k)
      server  = v.server
      email   = lookup(v, "email", local.acme_email)
      key_ref = lookup(v, "private_key_secret_name", "letsencrypt-${k}-account-key")
      solvers = v.solvers
      # Escape hatch for ACME keys this module does not name (live carries
      # disableAccountKeyGeneration on the Google Trust Services pair). Without it an adopted
      # issuer silently LOSES any field the module did not think to model.
      acme_extra = lookup(v, "acme_extra", {})
    }
  }
  environments = merge(
    { for k, v in local.builtin_issuers : k => v if local.manage_cluster_issuers && !local.use_spec_issuers },
    { for k, v in local.spec_issuers : k => v if local.manage_cluster_issuers },
  )

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
