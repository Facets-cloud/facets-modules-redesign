# ── GCP Service Account ───────────────────────────────────────────────────────
resource "google_service_account" "loki_gcs" {
  account_id   = local.sa_name
  project      = local.project
  display_name = "Loki GCS backend service account"

  lifecycle {
    ignore_changes = [account_id]
  }
}

# ── Custom IAM Role — minimal GCS permissions ─────────────────────────────────
resource "google_project_iam_custom_role" "loki_gcs" {
  role_id     = replace("${var.instance_name}_${local.env_name}_lokiGcsRole", "-", "_")
  project     = local.project
  title       = "Loki GCS backend role (${var.instance_name})"
  description = "Minimal permissions for Loki to read/write GCS bucket"
  permissions = [
    "storage.buckets.get",
    "storage.objects.create",
    "storage.objects.delete",
    "storage.objects.get",
    "storage.objects.list",
  ]
}

# ── Bind custom role to the service account at project level ──────────────────
resource "google_project_iam_member" "loki_gcs" {
  project = local.project
  role    = google_project_iam_custom_role.loki_gcs.id
  member  = "serviceAccount:${google_service_account.loki_gcs.email}"
}

# ── Bind GCS bucket IAM so the SA can access the bucket ───────────────────────
resource "google_storage_bucket_iam_binding" "loki_gcs" {
  bucket = local.bucket_name
  role   = google_project_iam_custom_role.loki_gcs.id
  members = [
    "serviceAccount:${google_service_account.loki_gcs.email}",
  ]
}

# ── Workload Identity — allow k8s SA to impersonate the GCP SA ────────────────
# Unified grafana/loki chart creates k8s SA named <release> (the release name itself)
resource "google_service_account_iam_member" "loki_gcs_workload_identity" {
  service_account_id = google_service_account.loki_gcs.id
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${local.project}.svc.id.goog[${local.namespace}/${var.instance_name}]"
}

# ── Helm: grafana/loki (unified chart) ────────────────────────────────────────
resource "helm_release" "loki" {
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki"
  name             = var.instance_name
  version          = local.loki_chart_version
  namespace        = local.namespace
  create_namespace = true
  cleanup_on_fail  = true
  timeout          = 600
  wait             = true

  values = [
    yamlencode(local.default_loki_values),
    yamlencode(local.loki_user_values),
  ]
}

# ── Helm: promtail ────────────────────────────────────────────────────────────
resource "helm_release" "promtail" {
  count = local.promtail_enabled ? 1 : 0

  depends_on       = [helm_release.loki]
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "promtail"
  name             = "${var.instance_name}-promtail"
  version          = local.promtail_chart_version
  namespace        = local.namespace
  create_namespace = true
  cleanup_on_fail  = true
  timeout          = 600
  wait             = false

  values = [
    yamlencode(local.default_promtail_values),
    yamlencode(local.promtail_user_values),
  ]
}

# ── Grafana datasource ConfigMap (picked up by Grafana sidecar) ───────────────
resource "kubernetes_config_map_v1" "grafana_loki_datasource" {
  depends_on = [helm_release.loki]

  metadata {
    name      = "${var.instance_name}-loki-datasource"
    namespace = local.namespace
    labels = {
      grafana_datasource = "1"
      datasource_name    = var.instance_name
    }
  }

  data = {
    "datasource-loki-${var.instance_name}.yaml" = yamlencode({
      apiVersion = 1
      datasources = [
        {
          name      = "Loki ${var.instance_name}"
          type      = "loki"
          url       = "http://${local.loki_endpoint}"
          access    = "proxy"
          isDefault = false
          jsonData = {
            timeout = 300
          }
        }
      ]
    })
  }
}
