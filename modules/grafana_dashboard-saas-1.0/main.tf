locals {
  advanced         = lookup(var.instance, "advanced", {})
  spec             = lookup(var.instance, "spec", {})
  advanced_default = lookup(local.advanced, "default", {})
  preserve_uid     = lookup(local.spec, "preserve_uid", lookup(local.advanced_default, "preserve_uid", false))
  uid_override     = local.preserve_uid ? {} : { uid = random_string.uid.result }
  metadata         = lookup(var.instance, "metadata", {})
}

resource "random_string" "uid" {
  length      = 16
  min_numeric = 5
  special     = false
}

resource "kubernetes_config_map" "grafana-dashboard-configmap" {
  metadata {
    name = var.instance_name
    labels = merge({
      grafana_dashboard = "1",
      dashboard_name    = var.instance_name
      },
      lookup(var.instance.metadata, "labels", {})
    )
    annotations = lookup(var.instance.metadata, "annotations", {})
    namespace   = lookup(local.metadata, "namespace", var.environment.namespace)
  }
  data = {
    "grafana-dashboard-${var.instance_name}.json" = jsonencode(merge(
      try(jsondecode(base64decode(var.instance.spec.dashboard_b64)), lookup(var.instance.spec, "dashboard", {})),
      local.uid_override
    ))
  }

  # saas-cp stays the live owner until handoff; never overwrite its dashboards (1155 incident)
  lifecycle {
    ignore_changes = [data]
  }
}