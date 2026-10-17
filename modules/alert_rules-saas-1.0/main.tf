locals {
  # values_b64 = base64(JSON of the exact live helm config) so the CP DB serializer
  # cannot mangle empty strings or bare "=" values in rule expressions.
  values = jsondecode(base64decode(var.instance.spec.values_b64))
}

resource "helm_release" "main" {
  name             = var.instance_name
  chart            = "${path.module}/cc-prometheus-rules-template-0.2.15.tgz"
  version          = "0.2.15"
  namespace        = lookup(lookup(var.instance, "spec", {}), "namespace", "default")
  cleanup_on_fail  = true
  create_namespace = false

  values = [jsonencode(local.values)]

  # saas-cp stays the live owner until handoff; never overwrite its values (1155 incident)
  lifecycle {
    ignore_changes = [
      values, chart, version, repository,
      create_namespace, max_history, wait, cleanup_on_fail, atomic, timeout, name,
    ]
  }
}
