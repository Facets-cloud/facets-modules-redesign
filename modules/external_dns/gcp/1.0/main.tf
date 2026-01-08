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

# Kubernetes secret with GCP DNS credentials
resource "kubernetes_secret" "external_dns_gcp_secret" {
  depends_on = [kubernetes_namespace.namespace]
  metadata {
    name      = local.secret_name
    namespace = local.namespace
  }
  data = {
    # Handle null data gracefully - use try() to safely access nested data
    "credentials.json" = try(
      lookup(try(data.kubernetes_secret_v1.dns.data, {}), "credentials.json", null),
      ""
    )
  }
}

# Deploy external-dns Helm chart
resource "helm_release" "external_dns" {
  depends_on       = [kubernetes_secret.external_dns_gcp_secret]
  name             = module.helm_name.name
  chart            = "external-dns"
  repository       = "oci://registry-1.docker.io/bitnamicharts"
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
      provider      = "google"
      txtOwnerId    = "${module.helm_name.name}-${var.environment.unique_name}"
      txtSuffix     = var.environment.unique_name
      policy        = "sync"
      domainFilters = local.domain_filters
      priorityClassName = "facets-critical"

      image = {
        registry   = "docker.io"
        repository = "bitnamilegacy/external-dns"
      }

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

      metrics = {
        serviceMonitor = {
          enabled = true
        }
      }

      google = {
        project = local.project_id
        serviceAccountSecret    = local.secret_name
        serviceAccountSecretKey = "credentials.json"
        zoneVisibility          = local.zone_visibility
        batchChangeSize         = local.batch_change_size
      }

      nodeSelector = local.node_selector
      tolerations  = local.tolerations
    }),
    yamlencode(local.user_supplied_helm_values)
  ]
}
