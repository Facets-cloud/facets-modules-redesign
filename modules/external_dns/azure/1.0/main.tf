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
    # Use client_secret directly from cloud_account input
    "client-secret" = var.inputs.cloud_account.attributes.client_secret
  }
}

# Create azure.json ConfigMap for kubernetes-sigs external-dns chart
# The official chart expects Azure credentials in /etc/kubernetes/azure.json file
resource "kubernetes_config_map" "azure_json" {
  depends_on = [kubernetes_namespace.namespace]
  metadata {
    name      = "${module.helm_name.name}-azure-config"
    namespace = local.namespace
  }
  data = {
    "azure.json" = jsonencode({
      tenantId        = local.tenant_id
      subscriptionId  = local.subscription_id
      resourceGroup   = local.resource_group_name
      aadClientId     = local.client_id
      aadClientSecret = var.inputs.cloud_account.attributes.client_secret
    })
  }
}

# Deploy external-dns Helm chart
resource "helm_release" "external_dns" {
  depends_on = [
    kubernetes_secret.external_dns_azure_secret,
    kubernetes_config_map.azure_json
  ]
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
      # kubernetes-sigs chart expects credentials via azure.json file mounted as volume
      azure = {
        resourceGroup = local.resource_group_name
        # Note: tenantId, subscriptionId, aadClientId, aadClientSecret are read from
        # /etc/kubernetes/azure.json file mounted via extraVolumes/extraVolumeMounts
      }

      # Mount azure.json ConfigMap as volume
      extraVolumes = [
        {
          name = "azure-config"
          configMap = {
            name = kubernetes_config_map.azure_json.metadata[0].name
          }
        }
      ]

      extraVolumeMounts = [
        {
          name      = "azure-config"
          mountPath = "/etc/kubernetes"
          readOnly  = true
        }
      ]

      # Node scheduling
      nodeSelector = local.node_selector
      tolerations  = local.tolerations

      # Priority class
      priorityClassName = local.priority_class_name
    }),
    yamlencode(local.user_supplied_helm_values)
  ]
}
