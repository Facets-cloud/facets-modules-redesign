# Name generation for GCP resources
module "service_account_name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 30
  globally_unique = false
  resource_name   = local.cluster_name
  resource_type   = "external-dns"
  is_k8s          = false
}

module "helm_name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 53
  globally_unique = false
  resource_name   = var.instance_name
  resource_type   = "externaldns"
  is_k8s          = true
}

# GCP Service Account for Cloud DNS access
resource "google_service_account" "external_dns_sa" {
  account_id   = local.service_account_id
  display_name = "external-dns-${local.cluster_name}"
  description  = "Service account for external-dns to manage Cloud DNS records"
  project      = local.project_id
}

# Grant Cloud DNS permissions to the service account
resource "google_project_iam_member" "external_dns_dns_admin" {
  project = local.project_id
  role    = "roles/dns.admin"
  member  = "serviceAccount:${google_service_account.external_dns_sa.email}"
}

# Create service account key
resource "google_service_account_key" "external_dns_key" {
  service_account_id = google_service_account.external_dns_sa.name
}

# Kubernetes namespace for external-dns
resource "kubernetes_namespace" "namespace" {
  metadata {
    name = local.namespace
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
    "credentials.json" = base64decode(google_service_account_key.external_dns_key.private_key)
  }
}

# Deploy external-dns Helm chart
resource "helm_release" "external_dns" {
  depends_on       = [kubernetes_secret.external_dns_gcp_secret]
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
      provider = "google"
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

      # Image configuration (official external-dns image from registry.k8s.io)
      # The kubernetes-sigs chart doesn't properly construct image from registry+repository+tag
      # Use full image path in repository field (matches manual fix that worked)
      image = {
        repository = "${local.image_registry}/${local.image_repository}"
        tag        = local.image_tag != "" ? local.image_tag : "v0.14.2"
        pullPolicy = "IfNotPresent"
        # Ensure registry is not set separately (chart might use it incorrectly)
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

      # GCP credentials via mounted secret
      # The external-dns GCP provider uses Google Cloud SDK which reads credentials from a JSON file
      # specified by GOOGLE_APPLICATION_CREDENTIALS environment variable
      env = [
        {
          name  = "GOOGLE_APPLICATION_CREDENTIALS"
          value = "/etc/gcp/credentials.json"
        },
        {
          name  = "GOOGLE_PROJECT"
          value = local.project_id
        }
      ]

      extraVolumes = [
        {
          name = "gcp-credentials"
          secret = {
            secretName = local.secret_name
          }
        }
      ]

      extraVolumeMounts = [
        {
          name      = "gcp-credentials"
          mountPath = "/etc/gcp"
          readOnly  = true
        }
      ]

      # GCP provider configuration
      google = {
        project         = local.project_id
        zoneVisibility  = local.zone_visibility
        batchChangeSize = local.batch_change_size
      }

      # Node scheduling
      nodeSelector = local.node_selector
      tolerations  = local.tolerations

      # Priority class
      priorityClassName = local.priority_class_name
    }),
    yamlencode(local.user_supplied_helm_values)
  ]
}
