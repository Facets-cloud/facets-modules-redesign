module "name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  is_k8s          = true
  globally_unique = false
  resource_type   = "kafka-topic"
  resource_name   = var.instance_name
  environment     = var.environment
  limit           = 40
}

module "kafka_topics" {
  source         = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resources"
  name           = module.name.name
  release_name   = "${module.name.name}-${substr(md5(local.cluster_name), 0, 8)}"
  namespace      = local.namespace
  resources_data = local.kafka_topic_manifests

  advanced_config = {}
}
