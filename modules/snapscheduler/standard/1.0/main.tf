module "name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 48
  resource_name   = var.instance_name
  resource_type   = "snapscheduler"
  globally_unique = true
}

resource "helm_release" "snapschedule" {
  name             = "snapscheduler"
  chart            = "${path.module}/snapscheduler-3.2.0.tgz"
  cleanup_on_fail  = true
  namespace        = local.namespace
  create_namespace = lookup(var.instance.spec, "create_namespace", true)
  wait             = lookup(var.instance.spec, "wait", true)
  atomic           = lookup(var.instance.spec, "atomic", false)
  timeout          = lookup(var.instance.spec, "timeout", 600)
  recreate_pods    = lookup(var.instance.spec, "recreate_pods", false)

  values = [
    yamlencode(local.final_values)
  ]
}
