module "name_dockerhub" {
  for_each        = local.artifactories_dockerhub != {} ? local.secret_metadata : {}
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  is_k8s          = true
  globally_unique = false
  resource_type   = "registry"
  resource_name   = replace(lower("${local.name}-${each.key}"), "_", "-")
  environment     = var.environment
  limit           = 63
}

resource "kubernetes_secret_v1" "registry_secret" {
  for_each = local.artifactories_dockerhub != {} ? local.secret_metadata : {}
  metadata {
    name      = module.name_dockerhub[each.key].name
    namespace = local.namespace
    labels    = lookup(local.metadata, "labels", {})
  }
  data = {
    ".dockerconfigjson" : each.value.dockerconfigjson
  }
  type = "kubernetes.io/dockerconfigjson"
}
