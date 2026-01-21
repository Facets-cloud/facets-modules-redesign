# PostgreSQL Monitoring Module - Complete Monitoring Stack for CloudSQL
# Deploys: PostgreSQL Exporter with CloudSQL Proxy, ServiceMonitor, PrometheusRules
#
# Versions:
# - Helm Chart: prometheus-postgres-exporter v6.5.0
# - App Version: postgres_exporter v0.15.0
# - CloudSQL Proxy: v2.8.0
# - Compatible with PostgreSQL 13, 14, 15, 16, 17


# ========================================
# Kubernetes Secret for PostgreSQL Credentials
# ========================================
resource "kubernetes_secret_v1" "postgres_credentials" {
  count = local.enable_metrics ? 1 : 0

  metadata {
    name      = "${local.name}-postgres-credentials"
    namespace = local.postgres_namespace
    labels    = local.common_labels
  }

  data = {
    DATA_SOURCE_URI  = local.postgres_data_source_uri
    DATA_SOURCE_USER = local.postgres_username
    DATA_SOURCE_PASS = local.postgres_password
  }

  type = "Opaque"
}


# ========================================
# Kubernetes Service Account for Workload Identity
# ========================================
resource "kubernetes_service_account_v1" "postgres_exporter_sa" {
  count = local.enable_metrics ? 1 : 0

  metadata {
    name      = "${local.name}-postgres-exporter-sa"
    namespace = local.postgres_namespace
    labels    = local.common_labels
    annotations = {
      "iam.gke.io/gcp-service-account" = "${local.name}-cloudsql@${local.gcp_project_id}.iam.gserviceaccount.com"
    }
  }
}


# ========================================
# GCP Service Account for CloudSQL Proxy
# ========================================
resource "google_service_account" "cloudsql_proxy_sa" {
  count = local.enable_metrics ? 1 : 0

  account_id   = "${local.name}-cloudsql"
  display_name = "Service Account for CloudSQL Proxy - ${var.instance_name}"
  description  = "Used by CloudSQL Proxy in PostgreSQL exporter for Facets monitoring"
  project      = local.gcp_project_id
}


# ========================================
# IAM Binding for CloudSQL Client Role
# ========================================
resource "google_project_iam_member" "cloudsql_client" {
  count = local.enable_metrics ? 1 : 0

  project = local.gcp_project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloudsql_proxy_sa[0].email}"
}


# ========================================
# Workload Identity Binding (K8s SA -> GCP SA)
# ========================================
resource "google_service_account_iam_member" "workload_identity_binding" {
  count = local.enable_metrics ? 1 : 0

  service_account_id = google_service_account.cloudsql_proxy_sa[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${local.gcp_project_id}.svc.id.goog[${local.postgres_namespace}/${local.name}-postgres-exporter-sa]"
}


# ========================================
# PostgreSQL Exporter Deployment via Helm
# ========================================
resource "helm_release" "postgres_exporter" {
  count = local.enable_metrics ? 1 : 0

  name       = "${local.name}-exporter"
  namespace  = local.postgres_namespace
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-postgres-exporter"
  version    = "6.5.0" # Helm chart version (app version v0.15.0)

  values = [
    yamlencode(
      merge(
        {
          # Use custom service account with Workload Identity
          serviceAccount = {
            create = false
            name   = kubernetes_service_account_v1.postgres_exporter_sa[0].metadata[0].name
          }

          # PostgreSQL connection configuration via secret
          config = {
            datasource = {
              # Connection will be via CloudSQL Proxy on localhost:5432
              host = "localhost"
              port = 5432
              user = local.postgres_username
              passwordSecret = {
                name = kubernetes_secret_v1.postgres_credentials[0].metadata[0].name
                key  = "DATA_SOURCE_PASS"
              }
              database = local.postgres_database
              sslmode  = "disable" # CloudSQL proxy handles encryption
            }
            # Enable extended metrics
            autoDiscoverDatabases  = true
            disableDefaultMetrics  = false
            disableSettingsMetrics = false
          }

          # CloudSQL Proxy sidecar container
          extraContainers = [
            {
              name  = "cloud-sql-proxy"
              image = "gcr.io/cloud-sql-connectors/cloud-sql-proxy:${local.cloudsql_proxy_config.image_tag}"
              args = [
                "--structured-logs",
                "--port=5432",
                "${local.cloudsql_instance_connection_name}"
              ]
              securityContext = {
                runAsNonRoot = true
                runAsUser    = 65532
                runAsGroup   = 65532
              }
              resources = local.cloudsql_proxy_config.resources
            }
          ]

          # ServiceMonitor configuration for Prometheus Operator
          serviceMonitor = {
            enabled       = true
            interval      = local.metrics_interval
            scrapeTimeout = "30s"

            additionalLabels = {
              # Required: Prometheus Operator uses serviceMonitorSelector.matchLabels.release
              # to discover ServiceMonitor resources
              release = var.inputs.prometheus.attributes.prometheus_release
            }

            # Metric relabeling: Add Facets resource labels to all metrics
            metricRelabelings = [
              {
                targetLabel = "facets_resource_type"
                replacement = "postgres"
              },
              {
                targetLabel = "facets_resource_name"
                replacement = var.instance_name
              }
            ]
          }

          service = {
            annotations = {
              "app.kubernetes.io/name"      = "postgresql-monitoring"
              "app.kubernetes.io/instance"  = var.instance_name
              "app.kubernetes.io/component" = "exporter"
            }
          }

          podAnnotations = {
            "app.kubernetes.io/name"      = "postgresql-monitoring"
            "app.kubernetes.io/instance"  = var.instance_name
            "app.kubernetes.io/component" = "exporter"
          }

          resources = local.resources
        },
        length(local.tolerations) > 0 ? {
          tolerations = local.tolerations
        } : {},

        length(local.node_selector) > 0 ? {
          nodeSelector = local.node_selector
        } : {},

        # Merge additional helm values provided by user
        lookup(var.instance.spec, "additional_helm_values", {})
      )
    )
  ]

  # Ensure service account and IAM bindings are created first
  depends_on = [
    kubernetes_service_account_v1.postgres_exporter_sa,
    google_service_account_iam_member.workload_identity_binding,
    google_project_iam_member.cloudsql_client
  ]
}


# ========================================
# PrometheusRule for Alerts
# ========================================

module "prometheus_rule" {
  count  = local.enable_alerts ? 1 : 0
  source = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"

  name         = local.name
  namespace    = local.prometheus_namespace
  release_name = "postgres-alerts-${substr(var.environment.unique_name, 0, 8)}"

  data = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"

    metadata = {
      name      = "${local.name}-alerts"
      namespace = local.prometheus_namespace
      labels = merge(
        local.common_labels,
        {
          release = var.inputs.prometheus.attributes.prometheus_release
        }
      )
    }

    spec = {
      groups = [
        {
          name     = "${var.instance_name}-postgresql-alerts"
          interval = "30s"
          rules    = local.alert_rules
        }
      ]
    }
  }

  advanced_config = {
    wait            = false
    timeout         = 300
    cleanup_on_fail = true
    max_history     = 3
  }
}
