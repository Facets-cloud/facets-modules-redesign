locals {
  spec = var.instance.spec

  # Use operator's namespace for Kafka resources (Strimzi requires resources in same namespace as operator)
  namespace = var.inputs.strimzi_operator.attributes.namespace

  # Extract version_config
  version_config = lookup(local.spec, "version_config", {})
  kafka_version  = lookup(local.version_config, "kafka_version", "4.0.0")
  admin_username = lookup(local.version_config, "admin_username", "admin")

  # Extract sizing
  sizing        = lookup(local.spec, "sizing", {})
  replica_count = lookup(local.sizing, "replica_count", 3)
  storage_size  = lookup(local.sizing, "storage_size", "10Gi")

  # Extract resources
  resources = lookup(local.sizing, "resources", {})
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

  # Get Kubernetes cluster details (providers configured automatically by Facets)
  k8s_cluster_input = lookup(var.inputs, "kubernetes_cluster", {})
  k8s_cluster_attrs = lookup(local.k8s_cluster_input, "attributes", {})

  # Get node pool details from input (if provided)
  node_pool_input  = lookup(var.inputs, "node_pool", {})
  node_pool_attrs  = lookup(local.node_pool_input, "attributes", {})
  node_selector    = lookup(local.node_pool_attrs, "node_selector", {})
  node_pool_taints = lookup(local.node_pool_attrs, "taints", [])

  # Get Strimzi operator details for dependency
  strimzi_operator_input = lookup(var.inputs, "strimzi_operator", {})
  operator_attributes    = lookup(local.strimzi_operator_input, "attributes", {})
  operator_namespace     = lookup(local.operator_attributes, "namespace", "kafka-system")
  operator_release       = lookup(local.operator_attributes, "release_name", "strimzi-operator")

  # Convert taints from {key, value, effect} to tolerations format
  tolerations = [
    for taint in local.node_pool_taints : {
      key      = taint.key
      operator = "Equal"
      value    = taint.value
      effect   = taint.effect
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
        pod = merge(
          {
            metadata = {
              labels = {
                workload = "database"
              }
            }
          },
          length(local.node_selector) > 0 ? {
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
          } : {},
          length(local.tolerations) > 0 ? {
            tolerations = local.tolerations
          } : {}
        )
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
        authorization = {
          type = "simple"
        }
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
              type = "topic"
              name = "*"
            }
            patternType = "literal"
            operations  = ["All"]
          },
          {
            resource = {
              type = "group"
              name = "*"
            }
            patternType = "literal"
            operations  = ["All"]
          },
          {
            resource = {
              type = "cluster"
            }
            patternType = "literal"
            operations  = ["All"]
          },
          {
            resource = {
              type = "transactionalId"
              name = "*"
            }
            patternType = "literal"
            operations  = ["All"]
          }
        ]
      }
    }
  }
}
