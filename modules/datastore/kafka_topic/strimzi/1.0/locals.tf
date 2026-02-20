locals {
  spec = var.instance.spec.topics

  # Get cluster details from kafka input
  kafka_cluster_attrs = var.inputs.kafka_cluster.attributes
  namespace           = local.kafka_cluster_attrs.namespace
  cluster_name        = local.kafka_cluster_attrs.cluster_name

  # Get Kubernetes cluster details
  k8s_cluster_input = lookup(var.inputs, "kubernetes_cluster", {})
  k8s_cluster_attrs = lookup(local.k8s_cluster_input, "attributes", {})

  # Build a KafkaTopic manifest for each topic entry
  kafka_topic_manifests = {
    for key, topic in local.spec : key => {
      apiVersion = "kafka.strimzi.io/v1beta2"
      kind       = "KafkaTopic"
      metadata = {
        name      = key
        namespace = local.namespace
        labels = {
          "strimzi.io/cluster" = local.cluster_name
        }
      }
      spec = merge(
        {
          partitions = topic.partitions
          replicas   = topic.replication_factor
        },
        length(topic.config) > 0 ? { config = topic.config } : {}
      )
    }
  }
}
