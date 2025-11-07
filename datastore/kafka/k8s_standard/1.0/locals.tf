# locals.tf - Local computations

locals {
  spec           = var.instance.spec
  namespace_meta = lookup(var.instance, "metadata", {})
  namespace      = lookup(local.namespace_meta, "namespace", "default")

  # Extract spec values
  kafka_version  = lookup(local.spec, "kafka_version", "4.0.0")
  replica_count  = lookup(local.spec, "replica_count", 3)
  storage_size   = lookup(local.spec, "storage_size", "10Gi")
  admin_username = lookup(local.spec, "admin_username", "admin")

  # Extract resources
  resources = lookup(local.spec, "resources", {})
  cpu       = lookup(local.resources, "cpu", "1")
  memory    = lookup(local.resources, "memory", "2Gi")

  # Extract listeners config
  listeners     = lookup(local.spec, "listeners", {})
  plain_enabled = lookup(local.listeners, "plain_enabled", true)
  tls_enabled   = lookup(local.listeners, "tls_enabled", true)

  # Extract Kafka config
  config                                   = lookup(local.spec, "config", {})
  offsets_topic_replication_factor         = lookup(local.config, "offsets_topic_replication_factor", 3)
  transaction_state_log_replication_factor = lookup(local.config, "transaction_state_log_replication_factor", 3)
  transaction_state_log_min_isr            = lookup(local.config, "transaction_state_log_min_isr", 2)
  default_replication_factor               = lookup(local.config, "default_replication_factor", 3)
  min_insync_replicas                      = lookup(local.config, "min_insync_replicas", 2)

  # Get node pool details from input
  node_pool_input  = lookup(var.inputs, "node_pool", {})
  node_pool_attrs  = lookup(local.node_pool_input, "attributes", {})
  node_selector    = lookup(local.node_pool_attrs, "node_selector", {})
  node_pool_taints = lookup(local.node_pool_attrs, "taints", {})

  # Get Strimzi operator Helm release name for dependency
  strimzi_operator_input = lookup(var.inputs, "strimzi_operator", {})
  operator_attributes    = lookup(local.strimzi_operator_input, "attributes", {})
  operator_release       = lookup(local.operator_attributes, "release_name", "unknown")

  # Convert taints to tolerations format
  tolerations = [
    for taint_name, taint_config in local.node_pool_taints : {
      key      = taint_config.key
      operator = "Equal"
      value    = taint_config.value
      effect   = taint_config.effect
    }
  ]

  # Generate node pool name for KafkaNodePool
  node_pool_name = "dual-role"

  # Generate bootstrap service name
  bootstrap_service = "${var.instance_name}-kafka-bootstrap"

  # Generate broker endpoints
  broker_endpoints = [
    for i in range(local.replica_count) :
    "${var.instance_name}-${local.node_pool_name}-${i}.${var.instance_name}-kafka-brokers.${local.namespace}.svc.cluster.local:9092"
  ]

  # Build listeners array with authentication
  listeners_config = concat(
    local.plain_enabled ? [{
      name = "plain"
      port = 9092
      type = "internal"
      tls  = false
      authentication = {
        type = "scram-sha-512"
      }
    }] : [],
    local.tls_enabled ? [{
      name = "tls"
      port = 9093
      type = "internal"
      tls  = true
      authentication = {
        type = "scram-sha-512"
      }
    }] : []
  )

  # KafkaNodePool manifest
  kafka_node_pool_manifest = {
    apiVersion = "kafka.strimzi.io/v1beta2"
    kind       = "KafkaNodePool"
    metadata = {
      name      = local.node_pool_name
      namespace = local.namespace
      labels = {
        "strimzi.io/cluster" = var.instance_name
      }
      annotations = {
        "facets.cloud/operator-release" = local.operator_release
      }
    }
    spec = {
      replicas = local.replica_count
      roles    = ["controller", "broker"]
      storage = {
        type        = "persistent-claim"
        size        = local.storage_size
        deleteClaim = false
      }
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
      template = {
        pod = {
          metadata = {
            labels = {
              workload = "database"
            }
          }
          affinity = {
            nodeAffinity = {
              requiredDuringSchedulingIgnoredDuringExecution = {
                nodeSelectorTerms = [
                  {
                    matchExpressions = [
                      for key, value in local.node_selector : {
                        key      = key
                        operator = "In"
                        values   = [value]
                      }
                    ]
                  }
                ]
              }
            }
          }
          tolerations = local.tolerations
        }
      }
    }
  }

  # Kafka CR manifest
  kafka_manifest = {
    apiVersion = "kafka.strimzi.io/v1beta2"
    kind       = "Kafka"
    metadata = {
      name      = var.instance_name
      namespace = local.namespace
      annotations = {
        "strimzi.io/node-pools"         = "enabled"
        "strimzi.io/kraft"              = "enabled"
        "facets.cloud/operator-release" = local.operator_release
      }
    }
    spec = {
      kafka = {
        version   = local.kafka_version
        listeners = local.listeners_config
        config = {
          "offsets.topic.replication.factor"         = local.offsets_topic_replication_factor
          "transaction.state.log.replication.factor" = local.transaction_state_log_replication_factor
          "transaction.state.log.min.isr"            = local.transaction_state_log_min_isr
          "default.replication.factor"               = local.default_replication_factor
          "min.insync.replicas"                      = local.min_insync_replicas
        }
      }
      entityOperator = {
        topicOperator = {}
        userOperator  = {}
      }
    }
  }

  # KafkaUser manifest for admin user
  kafka_user_manifest = {
    apiVersion = "kafka.strimzi.io/v1beta2"
    kind       = "KafkaUser"
    metadata = {
      name      = "${var.instance_name}-${local.admin_username}"
      namespace = local.namespace
      labels = {
        "strimzi.io/cluster" = var.instance_name
      }
      annotations = {
        "facets.cloud/operator-release" = local.operator_release
      }
    }
    spec = {
      authentication = {
        type = "scram-sha-512"
        password = {
          valueFrom = {
            secretKeyRef = {
              name = "${var.instance_name}-${local.admin_username}-password"
              key  = "password"
            }
          }
        }
      }
      authorization = {
        type = "simple"
        acls = [
          {
            resource = {
              type        = "topic"
              name        = "*"
              patternType = "literal"
            }
            operations = ["All"]
          },
          {
            resource = {
              type        = "group"
              name        = "*"
              patternType = "literal"
            }
            operations = ["All"]
          },
          {
            resource = {
              type        = "cluster"
              patternType = "literal"
            }
            operations = ["All"]
          },
          {
            resource = {
              type        = "transactionalId"
              name        = "*"
              patternType = "literal"
            }
            operations = ["All"]
          }
        ]
      }
    }
  }
}
