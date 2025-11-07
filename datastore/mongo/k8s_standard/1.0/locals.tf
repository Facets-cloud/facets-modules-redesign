# locals.tf - Local computations

locals {
  spec            = var.instance.spec
  namespace_meta  = lookup(var.instance, "metadata", {})
  namespace       = lookup(local.namespace_meta, "namespace", "default")
  database_name   = lookup(local.spec, "database_name", "admin")
  mongodb_version = lookup(local.spec, "mongodb_version", "7.0.15")
  replica_count   = lookup(local.spec, "replica_count", 3)
  admin_username  = lookup(local.spec, "admin_username", "admin")
  resources       = lookup(local.spec, "resources", {})
  cpu             = lookup(local.resources, "cpu", "1")
  memory          = lookup(local.resources, "memory", "2Gi")
  storage_size    = lookup(local.spec, "storage_size", "10Gi")

  # Get node pool details from input
  node_pool_input  = lookup(var.inputs, "node_pool", {})
  node_pool_attrs  = lookup(local.node_pool_input, "attributes", {})
  node_selector    = lookup(local.node_pool_attrs, "node_selector", {})
  node_pool_taints = lookup(local.node_pool_attrs, "taints", {})

  # Get MongoDB operator Helm release name for dependency
  mongodb_operator_input = lookup(var.inputs, "mongodb_operator", {})
  operator_attributes    = lookup(local.mongodb_operator_input, "attributes", {})
  operator_release       = lookup(local.operator_attributes, "release_name", "unknown")

  # Convert taints from {key: "key", value: "value", effect: "effect"} to tolerations format
  tolerations = [
    for taint_name, taint_config in local.node_pool_taints : {
      key      = taint_config.key
      operator = "Equal"
      value    = taint_config.value
      effect   = taint_config.effect
    }
  ]

  # Generate service name for replica set
  service_name = "${var.instance_name}-svc"

  # Generate individual replica hostnames
  replica_hosts = [
    for i in range(local.replica_count) :
    "${var.instance_name}-${i}.${local.service_name}.${local.namespace}.svc.cluster.local"
  ]

  # MongoDB CR manifest
  mongodb_manifest = {
    apiVersion = "mongodbcommunity.mongodb.com/v1"
    kind       = "MongoDBCommunity"
    metadata = {
      name      = var.instance_name
      namespace = local.namespace
      annotations = {
        "facets.cloud/operator-release" = local.operator_release
      }
    }
    spec = {
      members = local.replica_count
      type    = "ReplicaSet"
      version = local.mongodb_version
      security = {
        authentication = {
          modes = ["SCRAM"]
        }
      }
      users = [
        {
          name = local.admin_username
          db   = "admin"
          passwordSecretRef = {
            name = "${var.instance_name}-admin-password"
          }
          roles = [
            {
              name = "clusterAdmin"
              db   = "admin"
            },
            {
              name = "userAdminAnyDatabase"
              db   = "admin"
            },
            {
              name = "readWriteAnyDatabase"
              db   = "admin"
            }
          ]
          scramCredentialsSecretName = "${local.admin_username}-scram"
        }
      ]
      statefulSet = {
        spec = {
          volumeClaimTemplates = [
            {
              metadata = { name = "data-volume" }
              spec = {
                accessModes = ["ReadWriteOnce"]
                resources = {
                  requests = { storage = local.storage_size }
                }
              }
            },
            {
              metadata = { name = "logs-volume" }
              spec = {
                accessModes = ["ReadWriteOnce"]
                resources = {
                  requests = { storage = "2Gi" }
                }
              }
            }
          ]
          template = {
            spec = {
              nodeSelector = local.node_selector
              tolerations  = local.tolerations
              containers = [
                {
                  name = "mongod"
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
        }
      }
    }
  }
}
