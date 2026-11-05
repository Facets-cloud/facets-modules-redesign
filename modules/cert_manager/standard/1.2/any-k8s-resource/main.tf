

resource "helm_release" "k8s-resource" {
  name             = var.release_name == null ? var.name : var.release_name
  chart            = "${path.module}/dynamic-k8s-resource-0.1.0.tgz"
  timeout          = lookup(var.advanced_config, "timeout", 300)
  cleanup_on_fail  = lookup(var.advanced_config, "cleanup_on_fail", true)
  wait             = lookup(var.advanced_config, "wait", false)
  max_history      = lookup(var.advanced_config, "max_history", 10)
  version          = "0.1.0"
  create_namespace = lookup(var.advanced_config, "create_namespace", true)
  namespace        = var.namespace
  values = [
    yamlencode({
      resource = var.data
    }),
    yamlencode({
      resource = {
        metadata = {
          name      = var.name,
          namespace = var.namespace
          labels = {
            resourceName = var.name
            resourceType = "k8s_resource"
          }
        }
      }
    })
  ]

  # saas-cp stays the live owner until handoff; never overwrite its values (1155 incident)
  lifecycle {
    ignore_changes = [values, chart]
  }
}
