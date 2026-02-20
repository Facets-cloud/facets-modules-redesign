locals {
  output_attributes = {
    cluster_name = local.cluster_name
    namespace    = local.namespace
  }

  output_interfaces = {
    topics = {
      for key, topic in local.spec : key => {
        topic_name = key
        partitions = topic.partitions
        replicas   = topic.replicas
      }
    }
  }
}
