# locals.tf - Local computations

locals {
  spec                  = var.instance.spec
  namespace_meta        = lookup(var.instance, "metadata", {})
  namespace             = lookup(local.namespace_meta, "namespace", "elasticsearch-system")
  elasticsearch_version = lookup(local.spec, "elasticsearch_version", "8.11.0")
  replica_count         = lookup(local.spec, "replica_count", 3)
  resources             = lookup(local.spec, "resources", {})
  cpu                   = lookup(local.resources, "cpu", "1")
  memory                = lookup(local.resources, "memory", "2Gi")
  storage_size          = lookup(local.spec, "storage_size", "10Gi")

  # Get node pool details from input
  node_pool_input  = lookup(var.inputs, "node_pool", {})
  node_pool_attrs  = lookup(local.node_pool_input, "attributes", {})
  node_selector    = lookup(local.node_pool_attrs, "node_selector", {})
  node_pool_taints = lookup(local.node_pool_attrs, "taints", {})

  # Get ECK operator Helm release name for dependency
  eck_operator_input  = lookup(var.inputs, "eck_operator", {})
  operator_attributes = lookup(local.eck_operator_input, "attributes", {})
  operator_release    = lookup(local.operator_attributes, "release_name", "unknown")

  # Convert taints from {key: "key", value: "value", effect: "effect"} to tolerations format
  tolerations = [
    for taint_name, taint_config in local.node_pool_taints : {
      key      = taint_config.key
      operator = "Equal"
      value    = taint_config.value
      effect   = taint_config.effect
    }
  ]

  # Generate service names
  elasticsearch_service = "${var.instance_name}-es-http"
  elasticsearch_url     = "https://${local.elasticsearch_service}.${local.namespace}.svc.cluster.local:9200"

  # Decode the elastic password from the Kubernetes secret
  elastic_password = data.kubernetes_secret.elastic_user.data["elastic"]

  # Generate individual node hosts
  node_hosts = [
    for i in range(local.replica_count) :
    "${var.instance_name}-es-default-${i}.${var.instance_name}-es-default.${local.namespace}.svc.cluster.local"
  ]

  # Elasticsearch CR manifest
  elasticsearch_manifest = {
    apiVersion = "elasticsearch.k8s.elastic.co/v1"
    kind       = "Elasticsearch"
    metadata = {
      name      = var.instance_name
      namespace = local.namespace
      annotations = {
        "facets.cloud/operator-release" = local.operator_release
      }
    }
    spec = {
      version = local.elasticsearch_version
      nodeSets = [
        {
          name  = "default"
          count = local.replica_count
          config = {
            "node.roles" = ["master", "data", "ingest"]
          }
          podTemplate = {
            metadata = {}
            spec = {
              nodeSelector = local.node_selector
              tolerations  = local.tolerations
              containers = [
                {
                  name = "elasticsearch"
                  resources = {
                    requests = {
                      cpu    = local.cpu
                      memory = local.memory
                    }
                    limits = {
                      cpu    = local.cpu
                      memory = local.memory
                    }
                  }
                }
              ]
            }
          }
          volumeClaimTemplates = [
            {
              metadata = {
                name = "elasticsearch-data"
              }
              spec = {
                accessModes = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = local.storage_size
                  }
                }
              }
            }
          ]
        }
      ]
    }
  }
}
