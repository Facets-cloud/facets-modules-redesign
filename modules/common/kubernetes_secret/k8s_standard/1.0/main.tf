# Define your terraform resources here


module "facets-secret" {
  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = lower(var.instance_name)
  namespace       = local.namespace
  advanced_config = {}
  release_name    = "secret-${var.instance_name}"
  data = {
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name        = lower(var.instance_name)
      namespace   = local.namespace
      annotations = {}
      labels      = {}
    }
    data = {
      for k, v in lookup(local.spec, "data", {}) : v.key => base64encode(v.value)
    }
  }
}
