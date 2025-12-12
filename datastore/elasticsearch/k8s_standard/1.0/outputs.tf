locals {
  output_attributes = {
    namespace             = local.namespace
    cluster_name          = var.instance_name
    elasticsearch_service = local.elasticsearch_service
    elasticsearch_url     = local.elasticsearch_url
    replica_count         = local.replica_count
    elasticsearch_version = local.elasticsearch_version
    elastic_username      = "elastic"
    elastic_password      = sensitive(local.elastic_password)
    node_hosts            = local.node_hosts
    secrets               = ["elastic_password"]
  }
  output_interfaces = merge(
    {
      http = {
        host     = "${local.elasticsearch_service}.${local.namespace}.svc.cluster.local"
        port     = 9200
        username = "elastic"
        password = local.elastic_password
      }
      https = {
        host     = "${local.elasticsearch_service}.${local.namespace}.svc.cluster.local"
        port     = 9200
        username = "elastic"
        password = local.elastic_password
      }
    },
    # Add individual node interfaces
    {
      for i in range(local.replica_count) :
      "node${i + 1}" => {
        host     = local.node_hosts[i]
        port     = 9200
        username = "elastic"
        password = local.elastic_password
      }
    }
  )
}