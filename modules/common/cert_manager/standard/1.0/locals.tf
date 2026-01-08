# Define your locals here
locals {
  # Determine tenant provider from external_dns module output (primary) or kubernetes_details (cluster module output)
  tenant_provider = lower(
    try(var.inputs.external_dns_details.attributes.provider,
    try(var.inputs.kubernetes_details.attributes.cloud_provider, "aws"))
  )

  spec     = lookup(var.instance, "spec", {})
  advanced = lookup(var.instance, "advanced", {})

  # Helm values configuration
  cert_manager_advanced     = lookup(local.advanced, "cert_manager", {})
  user_supplied_helm_values = lookup(local.cert_manager_advanced, "values", {})
  cert_mgr_namespace        = "cert-manager"

  # DNS validation settings
  cnameStrategy          = lookup(local.spec, "cname_strategy", "Follow")
  disable_dns_validation = lookup(local.spec, "disable_dns_validation", false)

  # External DNS configuration (if provided)
  external_dns     = try(var.inputs.external_dns_details.attributes, null)
  has_external_dns = local.external_dns != null && !local.disable_dns_validation

  # Build DNS provider configuration from external_dns input
  # This creates the provider-specific configuration block for cert-manager
  dns_providers = local.has_external_dns ? merge(
    local.external_dns.provider == "aws" ? {
      route53 = {
        region = local.external_dns.region
        accessKeyIDSecretRef = {
          name      = local.external_dns.secret_name
          key       = local.external_dns.aws_access_key_id_key
          namespace = local.external_dns.secret_namespace
        }
        secretAccessKeySecretRef = {
          name      = local.external_dns.secret_name
          key       = local.external_dns.aws_secret_access_key_key
          namespace = local.external_dns.secret_namespace
        }
      }
    } : {},
    local.external_dns.provider == "gcp" ? {
      cloudDNS = {
        project = local.external_dns.project_id
        serviceAccountSecretRef = {
          name      = local.external_dns.secret_name
          key       = local.external_dns.gcp_credentials_json_key
          namespace = local.external_dns.secret_namespace
        }
      }
    } : {},
    local.external_dns.provider == "azure" ? {
      azureDNS = {
        subscriptionID    = local.external_dns.subscription_id
        tenantID          = local.external_dns.tenant_id
        clientID          = local.external_dns.client_id
        resourceGroupName = local.external_dns.resource_group_name
        clientSecretSecretRef = {
          name      = local.external_dns.secret_name
          key       = local.external_dns.azure_credentials_json_key
          namespace = local.external_dns.secret_namespace
        }
      }
    } : {}
  ) : {}
  # Let's Encrypt DNS01 validation cluster issuers
  dns01_validations = {
    staging = {
      name = "letsencrypt-staging"
      url  = "https://acme-staging-v02.api.letsencrypt.org/directory"
      solvers = [
        {
          dns01 = merge({
            cnameStrategy = local.cnameStrategy
          }, local.dns_providers)
        },
      ]
    }
    production = {
      name = "letsencrypt-prod"
      url  = "https://acme-v02.api.letsencrypt.org/directory"
      solvers = [
        {
          dns01 = merge({
            cnameStrategy = local.cnameStrategy
          }, local.dns_providers)
        },
      ]
    }
  }

  # Let's Encrypt HTTP01 validation cluster issuers
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
                  nodeSelector = local.nodeSelector
                  tolerations  = local.tolerations
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
                  nodeSelector = local.nodeSelector
                  tolerations  = local.tolerations
                }
              }
            }
          }
        },
      ]
    }
  }

  # Combine HTTP and DNS validations (skip DNS if disabled)
  environments = merge(
    local.http_validations,
    local.disable_dns_validation ? {} : local.dns01_validations
  )

  # Nodepool configuration from inputs
  nodepool_config = try(var.inputs.kubernetes_node_pool_details.attributes, null)

  # Handle taints: convert null/object to empty list, ensure it's always a list
  # taints can come as: null, {}, [], or list of objects with {key, value, effect}
  # Check if taints exists and is a list, otherwise return empty list
  # Use can() to safely check if we can convert to list (works for lists, fails for objects)
  nodepool_tolerations = local.nodepool_config != null && local.nodepool_config.taints != null ? (
    can(tolist(local.nodepool_config.taints)) ? tolist(local.nodepool_config.taints) : []
  ) : []

  nodepool_labels = local.nodepool_config != null ? try(local.nodepool_config.node_selector, {}) : {}

  # Use only nodepool configuration (no fallback to default tolerations)
  tolerations  = local.nodepool_tolerations
  nodeSelector = local.nodepool_labels

  # GTS and ACME configuration
  use_gts         = lookup(local.spec, "use_gts", false)
  gts_private_key = lookup(local.spec, "gts_private_key", "")
  acme_email      = lookup(local.spec, "acme_email", "") != "" ? lookup(local.spec, "acme_email", "") : null
}
