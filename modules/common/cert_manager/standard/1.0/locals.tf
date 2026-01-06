# Define your locals here
locals {
  tenant_provider           = lower(try(var.cc_metadata.cc_tenant_provider, try(var.inputs.external_dns_details.attributes.provider, "aws")))
  spec                      = lookup(var.instance, "spec", {})
  user_supplied_helm_values = try(local.spec.cert_manager.values, try(var.instance.advanced.cert_manager.values, {}))
  cert_manager              = lookup(local.spec, "cert_manager", try(var.instance.advanced.cert_manager, {}))
  cert_mgr_namespace        = "cert-manager"
  advanced                  = lookup(lookup(var.instance, "advanced", {}), "cert_manager", {})
  cnameStrategy             = lookup(local.spec, "cname_strategy", "Follow")
  disable_dns_validation    = lookup(local.spec, "disable_dns_validation", lookup(local.advanced, "disable_dns_validation", false))
  user_defined_tags         = try(local.cert_manager.tags, {})
  
  # External DNS configuration (if provided)
  external_dns              = try(var.inputs.external_dns_details.attributes, null)
  has_external_dns          = local.external_dns != null && !local.disable_dns_validation
  
  # Build DNS provider configuration from external_dns input
  dns_providers = local.has_external_dns ? (
    local.external_dns.provider == "aws" ? {
      route53 = {
        region = local.external_dns.region
        accessKeyIDSecretRef = {
          key  = local.external_dns.aws_access_key_id_key
          name = local.external_dns.secret_name
        }
        secretAccessKeySecretRef = {
          key  = local.external_dns.aws_secret_access_key_key
          name = local.external_dns.secret_name
        }
      }
    } : local.external_dns.provider == "gcp" ? {
      cloudDNS = {
        project = try(var.inputs.cloud_account.attributes.project, "")
        serviceAccountSecretRef = {
          key  = local.external_dns.gcp_credentials_json_key
          name = local.external_dns.secret_name
        }
      }
    } : local.external_dns.provider == "azure" ? {
      azureDNS = {
        subscriptionID = try(var.inputs.cloud_account.attributes.subscription_id, "")
        tenantID       = try(var.inputs.cloud_account.attributes.tenant_id, "")
        clientID       = try(var.inputs.cloud_account.attributes.client_id, "")
        clientSecretSecretRef = {
          key  = local.external_dns.azure_credentials_json_key
          name = local.external_dns.secret_name
        }
      }
    } : {}
  ) : {}
  dns01_validations = {
    staging = {
      name = "letsencrypt-staging"
      url  = "https://acme-staging-v02.api.letsencrypt.org/directory"
      solvers = [
        {
          dns01 = merge({
            cnameStrategy = "Follow"
          }, lookup(local.dns_providers, local.tenant_provider, {}))
        },
      ]
    }
    production = {
      name = "letsencrypt-prod"
      url  = "https://acme-v02.api.letsencrypt.org/directory"
      solvers = [
        {
          dns01 = merge({
            cnameStrategy = "Follow"
          }, lookup(local.dns_providers, local.tenant_provider, {}))
        },
      ]
    }
  }
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
  environments = merge(local.http_validations, local.disable_dns_validation ? {} : local.dns01_validations)

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
  acme_email      = lookup(local.spec, "acme_email", "") != "" ? lookup(local.spec, "acme_email", "") : try(var.cluster.createdBy, null)
}

# Fallback: Read existing DNS credentials secret if external_dns not provided (for GCP/Azure)
data "kubernetes_secret_v1" "dns" {
  count = local.has_external_dns ? 0 : (local.tenant_provider == "aws" ? 0 : 1)
  metadata {
    name      = "facets-tenant-dns"
    namespace = "default"
  }
  provider = kubernetes.release-pod
}
