resource "helm_release" "external_helm_charts" {
  chart               = var.instance.spec["helm"]["chart"]
  name                = var.instance_name
  namespace           = lookup(var.instance.spec["helm"], "namespace", var.environment.namespace)
  timeout             = lookup(var.instance.spec["helm"], "timeout", 300)
  create_namespace    = true
  wait                = lookup(var.instance.spec["helm"], "wait", true)
  repository          = lookup(var.instance.spec["helm"], "repository", "")
  version             = lookup(var.instance.spec["helm"], "version", "")
  recreate_pods       = lookup(var.instance.spec["helm"], "recreate_pods", false)
  repository_username = lookup(var.instance.spec["helm"], "repository_username", null)
  repository_password = lookup(var.instance.spec["helm"], "repository_password", null)
  cleanup_on_fail     = true

  values = [
    yamlencode(merge(
      lookup(var.instance.spec, "values", {}),
      {
        prometheus_id = try(var.inputs.prometheus_details.attributes.helm_release_id, "")
      }
    ))
  ]
}