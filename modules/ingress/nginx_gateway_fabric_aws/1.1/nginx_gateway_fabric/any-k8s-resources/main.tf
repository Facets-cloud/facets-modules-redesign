resource "helm_release" "k8s-resource" {
  name             = var.release_name == null ? var.name : var.release_name
  chart            = "${path.module}/dynamic-k8s-resources-0.1.0.tgz"
  timeout          = lookup(var.advanced_config, "timeout", 300)
  wait             = lookup(var.advanced_config, "wait", false)
  version          = "0.1.0"
  create_namespace = true
  max_history      = lookup(var.advanced_config, "max_history", 10)
  namespace        = var.namespace
  values = [
    jsonencode({
      resources = var.resources_data
    })
  ]

  # saas-cp stays the live owner of these releases until handoff; values drift there
  # (tenant routes) and must never be overwritten from this blueprint (1155 incident)
  lifecycle {
    ignore_changes = [values, chart]
  }
}
