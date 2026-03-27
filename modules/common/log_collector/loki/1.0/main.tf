# ── MinIO secret (generated, stable across applies via keepers) ───────────────
resource "random_password" "minio_secret" {
  count = local.is_minio_enabled ? 1 : 0

  length  = 32
  special = false
  keepers = {
    # Regenerate only if the instance name changes, not on every apply
    instance = var.instance_name
  }
}

# ── Namespace ─────────────────────────────────────────────────────────────────
resource "kubernetes_namespace" "namespace" {
  metadata {
    name = local.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "facets"
      "facets/instance"              = var.instance_name
    }
  }

  lifecycle {
    # Ignore annotation changes made by external controllers (e.g. Istio, OPA)
    ignore_changes = [metadata[0].annotations]
  }
}

# ── MinIO (conditional — only when S3 is NOT configured) ──────────────────────
resource "helm_release" "minio" {
  count = local.is_minio_enabled ? 1 : 0

  depends_on       = [kubernetes_namespace.namespace]
  name             = "${var.instance_name}-minio"
  repository       = "https://charts.min.io/"
  chart            = "minio"
  version          = "5.2.0"
  namespace        = local.namespace
  create_namespace = false
  cleanup_on_fail  = true
  wait             = true
  timeout          = 300

  # Two separate values entries: Helm deep-merges them natively.
  # This correctly handles nested overrides without Terraform's shallow merge().
  values = [
    yamlencode(local.constructed_minio_values),
    yamlencode(local.user_defined_minio_values != null ? local.user_defined_minio_values : {}),
  ]
}

# ── Loki Distributed ──────────────────────────────────────────────────────────
resource "helm_release" "loki" {
  # When S3 is used, depend only on the namespace.
  # When MinIO is used, also wait for MinIO to be ready before starting Loki.
  depends_on = [
    kubernetes_namespace.namespace,
    helm_release.minio,
  ]

  name             = "${var.instance_name}-loki"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki-distributed"
  version          = "0.79.3"
  namespace        = local.namespace
  create_namespace = false
  cleanup_on_fail  = true
  wait             = true
  timeout          = 600

  # Two separate values entries: Helm deep-merges them natively.
  # User overrides in spec.loki are applied on top of constructed defaults.
  values = [
    yamlencode(local.constructed_loki_values),
    yamlencode(local.user_defined_loki_values != null ? local.user_defined_loki_values : {}),
  ]

  lifecycle {
    precondition {
      condition     = !local.is_s3_enabled || local.s3_bucket != ""
      error_message = "spec.storage_config.s3.bucket_name must not be empty when S3 storage is configured."
    }
  }
}

# ── Promtail ──────────────────────────────────────────────────────────────────
resource "helm_release" "promtail" {
  depends_on       = [helm_release.loki]
  name             = "${var.instance_name}-promtail"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "promtail"
  version          = "6.16.4"
  namespace        = local.namespace
  create_namespace = false
  cleanup_on_fail  = true
  wait             = true
  timeout          = 300

  # Two separate values entries: Helm deep-merges them natively.
  values = [
    yamlencode(local.constructed_promtail_values),
    yamlencode(local.user_defined_promtail_values != null ? local.user_defined_promtail_values : {}),
  ]
}

# ── Grafana Datasource ConfigMap (optional) ───────────────────────────────────
# Placed in grafana_datasource_namespace (default: same as logging namespace).
# Set spec.grafana_datasource_namespace to match where Grafana is deployed
# so the Grafana sidecar can discover it automatically.
resource "kubernetes_config_map" "grafana_datasource" {
  count = local.enable_grafana_datasource ? 1 : 0

  depends_on = [helm_release.loki]

  metadata {
    name      = "${var.instance_name}-loki-datasource"
    namespace = local.grafana_datasource_namespace
    labels = {
      "grafana_datasource"           = "1"
      "app.kubernetes.io/managed-by" = "facets"
      "facets/instance"              = var.instance_name
    }
  }

  data = {
    "loki-datasource.yaml" = yamlencode(local.grafana_datasource)
  }
}
