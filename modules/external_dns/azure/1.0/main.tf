module "helm_name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 53
  globally_unique = false
  resource_name   = var.instance_name
  resource_type   = "externaldns"
  is_k8s          = true
}

# Kubernetes namespace for external-dns
resource "kubernetes_namespace" "namespace" {
  metadata {
    name = local.namespace
  }
}

# Read existing DNS credentials secret (created by platform)
data "kubernetes_secret_v1" "dns" {
  metadata {
    name      = "facets-tenant-dns"
    namespace = "default"
  }
}

# Kubernetes secret with Azure DNS credentials
# cert-manager expects the client secret in a key named "client-secret"
resource "kubernetes_secret" "external_dns_azure_secret" {
  depends_on = [kubernetes_namespace.namespace]
  metadata {
    name      = local.secret_name
    namespace = local.namespace
  }
  data = {
    # cert-manager azureDNS solver expects the key to be "client-secret"
    # Handle null data gracefully - use try() to safely access nested data
    "client-secret" = try(
      lookup(try(data.kubernetes_secret_v1.dns.data, {}), "client-secret", null),
      try(
        lookup(try(data.kubernetes_secret_v1.dns.data, {}), "credentials.json", null),
        ""
      )
    )
  }
}

# Deploy external-dns Helm chart
resource "helm_release" "external_dns" {
  depends_on       = [kubernetes_secret.external_dns_azure_secret]
  name             = module.helm_name.name
  chart            = local.chart_source
  repository       = local.chart_repository
  version          = local.helm_version
  namespace        = local.namespace
  create_namespace = false
  cleanup_on_fail  = local.cleanup_on_fail
  wait             = local.wait
  atomic           = local.atomic
  timeout          = local.timeout
  recreate_pods    = local.recreate_pods

  values = [
    yamlencode({
      # Provider configuration
      provider = "azure"
      policy   = "sync"

      # Domain filters
      domainFilters = local.domain_filters

      # TXT record configuration
      txtOwnerId = "${module.helm_name.name}-${var.environment.unique_name}"
      txtSuffix  = var.environment.unique_name

      # Service account configuration
      serviceAccount = {
        create = true
        name   = module.helm_name.name
      }

      # Image configuration (official external-dns image)
      image = local.image_tag != "" ? {
        registry   = local.image_registry
        repository = local.image_repository
        tag        = local.image_tag
        } : {
        registry   = local.image_registry
        repository = local.image_repository
      }

      # Resource limits
      resources = {
        limits = {
          cpu    = "500m"
          memory = "500Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "100Mi"
        }
      }

      # Metrics configuration
      metrics = {
        serviceMonitor = {
          enabled = true
        }
      }

      # Azure provider configuration
      azure = {
        resourceGroup      = local.resource_group_name
        tenantId           = local.tenant_id
        subscriptionId     = local.subscription_id
        aadClientId        = local.client_id
        aadClientSecret    = local.secret_name
        aadClientSecretKey = "client-secret"
      }

      # Node scheduling
      nodeSelector = local.node_selector
      tolerations  = local.tolerations

      # Priority class
      priorityClassName = "facets-critical"
    }),
    yamlencode(local.user_supplied_helm_values)
  ]
}
