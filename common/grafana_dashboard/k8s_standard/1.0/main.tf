locals {
  metadata        = lookup(var.instance, "metadata", {})
  spec            = lookup(var.instance, "spec", {})
  advanced        = lookup(var.instance, "advanced", {})
  advanced_default = lookup(local.advanced, "default", {})

  # Namespace handling - prefer metadata.namespace, fallback to environment.namespace
  namespace = lookup(local.metadata, "namespace", null) == null ? var.environment.namespace : var.instance.metadata.namespace

  # UID preservation logic
  preserve_uid = lookup(local.spec, "preserve_uid", lookup(local.advanced_default, "preserve_uid", false))
  uid_override = local.preserve_uid ? {} : { uid = random_string.uid.result }
}

resource "random_string" "uid" {
  length      = 16
  min_numeric = 5
  special     = false
}

resource "kubernetes_config_map" "grafana-dashboard-configmap" {
  metadata {
    name = lower(var.instance_name)
    labels = merge(
      {
        grafana_dashboard = "1",
        dashboard_name    = lower(var.instance_name)
      },
      lookup(local.metadata, "labels", {})
    )
    annotations = lookup(local.metadata, "annotations", {})
    namespace   = local.namespace
  }

  data = {
    "grafana-dashboard-${lower(var.instance_name)}.json" = jsonencode(merge(
      lookup(local.spec, "dashboard", {}),
      local.uid_override
    ))
  }
}
