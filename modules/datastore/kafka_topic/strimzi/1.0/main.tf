module "kafka_topics" {
  for_each = local.kafka_topic_manifests

  source       = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name         = "${var.instance_name}-${each.key}"
  release_name = "${var.instance_name}-${each.key}-${substr(md5(local.cluster_name), 0, 8)}"
  namespace    = local.namespace
  data         = each.value

  advanced_config = {}
}
