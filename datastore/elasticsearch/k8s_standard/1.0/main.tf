# main.tf - Elasticsearch ECK Operator Implementation

# Deploy Elasticsearch using any-k8s-resource
module "elasticsearch" {
  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = var.instance_name
  release_name    = var.instance_name
  namespace       = local.namespace
  data            = local.elasticsearch_manifest
  advanced_config = {}
}

# Read the elastic user password from the Kubernetes secret created by ECK operator
data "kubernetes_secret" "elastic_user" {
  metadata {
    name      = "${var.instance_name}-es-elastic-user"
    namespace = local.namespace
  }

  depends_on = [module.elasticsearch]
}
