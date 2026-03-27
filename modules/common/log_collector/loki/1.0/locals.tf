locals {
  # ── Base spec ────────────────────────────────────────────────────────────────
  spec      = lookup(var.instance, "spec", {})
  namespace = lookup(local.spec, "namespace", "logging")

  # ── Storage config ───────────────────────────────────────────────────────────
  storage_config   = lookup(local.spec, "storage_config", {})
  s3_config        = lookup(local.storage_config, "s3", null)
  is_s3_enabled    = local.s3_config != null
  is_minio_enabled = !local.is_s3_enabled

  s3_bucket     = local.is_s3_enabled ? lookup(local.s3_config, "bucket_name", "") : ""
  s3_region     = local.is_s3_enabled ? lookup(local.s3_config, "region", "us-east-1") : "us-east-1"
  s3_access_key = local.is_s3_enabled ? lookup(local.s3_config, "access_key_id", "") : ""
  s3_secret_key = local.is_s3_enabled ? lookup(local.s3_config, "secret_access_key", "") : ""

  # ── Sizing config ────────────────────────────────────────────────────────────
  loki_size          = lookup(local.spec, "loki_size", {})
  promtail_size      = lookup(local.spec, "promtail_size", {})
  log_retention_days = lookup(local.spec, "log_retention_days", 7)
  container_runtime  = lookup(local.spec, "container_runtime", "cri")

  # ── Loki behaviour toggles ───────────────────────────────────────────────────
  auth_enabled       = lookup(local.spec, "auth_enabled", false)
  replication_factor = lookup(local.spec, "replication_factor", 1)

  # ── Grafana datasource toggles ───────────────────────────────────────────────
  enable_grafana_datasource    = lookup(local.spec, "enable_grafana_datasource", true)
  grafana_datasource_namespace = lookup(local.spec, "grafana_datasource_namespace", local.namespace)

  # ── Node pool config — use try() to safely access optional typed object ──────
  tolerations   = try(var.inputs.kubernetes_node_pool_details.attributes.taints, [])
  node_selector = try(var.inputs.kubernetes_node_pool_details.attributes.node_selector, {})

  # ── Prometheus integration ───────────────────────────────────────────────────
  prometheus_enabled = try(var.inputs.prometheus_details.attributes.helm_release_id, "") != ""

  # ── Loki internal query endpoint ─────────────────────────────────────────────
  loki_url = "http://${var.instance_name}-loki-gateway.${local.namespace}.svc.cluster.local"

  # ── User-defined Helm overrides (passed as second values entry for Helm deep merge)
  user_defined_loki_values     = lookup(local.spec, "loki", {})
  user_defined_promtail_values = lookup(local.spec, "promtail", {})
  user_defined_minio_values    = lookup(local.spec, "minio", {})

  # ── Grafana datasource ConfigMap data ────────────────────────────────────────
  grafana_datasource = {
    apiVersion = 1
    datasources = [
      {
        name      = "Loki"
        type      = "loki"
        url       = local.loki_url
        access    = "proxy"
        isDefault = false
        jsonData = {
          timeout  = 60
          maxLines = 1000
        }
      }
    ]
  }
}

# ── Outputs ───────────────────────────────────────────────────────────────────
locals {
  output_attributes = {
    loki_url        = local.loki_url
    namespace       = local.namespace
    storage_type    = local.is_s3_enabled ? "s3" : "minio"
    helm_release_id = "${var.instance_name}-loki"
  }
  output_interfaces = {}
}
