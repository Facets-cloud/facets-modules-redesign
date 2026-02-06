# Redis Cluster Module - KubeBlocks v1.0.1
# Creates and manages Redis clusters using KubeBlocks operator
# REQUIRES: KubeBlocks operator must be deployed first (CRDs must exist)


# Redis Cluster with Embedded Backup Configuration
# Using any-k8s-resource module to avoid plan-time CRD validation
# Backup is configured via spec.backup (ClusterBackup API)
module "redis_cluster" {
  source = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"

  name         = local.cluster_name
  namespace    = local.namespace
  release_name = "redis-${local.cluster_name}-${substr(var.inputs.kubeblocks_operator.attributes.release_id, 0, 8)}"

  data = {
    apiVersion = "apps.kubeblocks.io/v1"
    kind       = "Cluster"

    metadata = {
      name      = local.cluster_name
      namespace = local.namespace

      annotations = merge(
        {
          "kubeblocks.io/operator-release-id" = var.inputs.kubeblocks_operator.attributes.release_id
        },
        local.restore_enabled && local.restore_backup_name != "" ? {
          "kubeblocks.io/restore-from-backup" = jsonencode({
            redis = {
              name      = local.restore_backup_name
              namespace = local.namespace
            }
          })
        } : {}
      )

      labels = merge(
        {
          "app.kubernetes.io/name"       = "redis"
          "app.kubernetes.io/instance"   = var.instance_name
          "app.kubernetes.io/managed-by" = "terraform"
          "app.kubernetes.io/version"    = var.instance.spec.redis_version
        },
        local.restore_enabled ? {
          "dataprotection.kubeblocks.io/restore-source" = local.restore_backup_name
        } : {},
        var.environment.cloud_tags
      )
    }

    spec = merge(
      {
        terminationPolicy = var.instance.spec.termination_policy
      },
      local.mode != "redis-cluster" ? {
        clusterDef = "redis"
        topology   = local.topology
      } : {},

      local.mode == "redis-cluster" ? {
        shardings = [
          {
            name   = "shard"
            shards = local.shards

            template = {
              name           = "redis"
              componentDef   = local.component_def
              serviceVersion = local.redis_version
              replicas       = local.replicas

              resources = {
                limits = {
                  cpu    = var.instance.spec.resources.cpu_limit
                  memory = var.instance.spec.resources.memory_limit
                }
                requests = {
                  cpu    = var.instance.spec.resources.cpu_request
                  memory = var.instance.spec.resources.memory_request
                }
              }

              volumeClaimTemplates = [
                {
                  name = "data"
                  spec = merge(
                    {
                      accessModes = ["ReadWriteOnce"]
                      resources = {
                        requests = {
                          storage = var.instance.spec.storage.size
                        }
                      }
                    },
                    {
                      storageClassName = var.instance.spec.storage.storage_class
                    }
                  )
                }
              ]

              schedulingPolicy = merge(
                local.enable_pod_anti_affinity ? {
                  affinity = {
                    podAntiAffinity = {
                      preferredDuringSchedulingIgnoredDuringExecution = [
                        {
                          weight = 100
                          podAffinityTerm = {
                            labelSelector = {
                              matchLabels = {
                                "app.kubernetes.io/instance"        = local.cluster_name
                                "app.kubernetes.io/managed-by"      = "kubeblocks"
                                "apps.kubeblocks.io/component-name" = "redis"
                              }
                            }
                            topologyKey = "kubernetes.io/hostname"
                          }
                        }
                      ]
                    }
                  }
                } : {},
                # Node selector (if provided)
                length(local.node_selector) > 0 ? {
                  nodeSelector = local.node_selector
                } : {},
                # Tolerations - dynamic from node pool taints
                {
                  tolerations = local.tolerations
                }
              )
            }
          }
        ]
      } : {},
      local.mode != "redis-cluster" ? {
        componentSpecs = concat(
          [
            merge(
              {
                name           = "redis"
                componentDef   = local.component_def
                serviceVersion = local.redis_version
                replicas       = local.replicas

                resources = {
                  limits = {
                    cpu    = var.instance.spec.resources.cpu_limit
                    memory = var.instance.spec.resources.memory_limit
                  }
                  requests = {
                    cpu    = var.instance.spec.resources.cpu_request
                    memory = var.instance.spec.resources.memory_request
                  }
                }

                volumeClaimTemplates = [
                  {
                    name = "data"
                    spec = merge(
                      {
                        accessModes = ["ReadWriteOnce"]
                        resources = {
                          requests = {
                            storage = var.instance.spec.storage.size
                          }
                        }
                      },
                      var.instance.spec.storage.storage_class != "" ? {
                        storageClassName = var.instance.spec.storage.storage_class
                      } : {}
                    )
                  }
                ]
              },

              {
                schedulingPolicy = merge(
                  local.enable_pod_anti_affinity ? {
                    affinity = {
                      podAntiAffinity = {
                        preferredDuringSchedulingIgnoredDuringExecution = [
                          {
                            weight = 100
                            podAffinityTerm = {
                              labelSelector = {
                                matchLabels = {
                                  "app.kubernetes.io/instance"        = local.cluster_name
                                  "app.kubernetes.io/managed-by"      = "kubeblocks"
                                  "apps.kubeblocks.io/component-name" = "redis"
                                }
                              }
                              topologyKey = "kubernetes.io/hostname"
                            }
                          }
                        ]
                      }
                    }
                  } : {},
                  # Node selector (if provided)
                  length(local.node_selector) > 0 ? {
                    nodeSelector = local.node_selector
                  } : {},
                  # Tolerations - dynamic from node pool taints
                  {
                    tolerations = local.tolerations
                  }
                )
              }
            )
          ],
          # Add redis-sentinel component for replication mode
          local.topology == "replication" ? [
            {
              name           = "redis-sentinel"
              componentDef   = local.sentinel_component_def
              serviceVersion = local.sentinel_version
              replicas       = local.sentinel_replicas

              resources = {
                limits = {
                  cpu    = var.instance.spec.resources.cpu_limit
                  memory = var.instance.spec.resources.memory_limit
                }
                requests = {
                  cpu    = var.instance.spec.resources.cpu_request
                  memory = var.instance.spec.resources.memory_request
                }
              }

              volumeClaimTemplates = [
                {
                  name = "data"
                  spec = merge(
                    {
                      accessModes = ["ReadWriteOnce"]
                      resources = {
                        requests = {
                          storage = var.instance.spec.storage.size
                        }
                      }
                    },
                    var.instance.spec.storage.storage_class != "" ? {
                      storageClassName = var.instance.spec.storage.storage_class
                    } : {}
                  )
                }
              ]

              schedulingPolicy = merge(
                local.enable_pod_anti_affinity ? {
                  affinity = {
                    podAntiAffinity = {
                      preferredDuringSchedulingIgnoredDuringExecution = [
                        {
                          weight = 100
                          podAffinityTerm = {
                            labelSelector = {
                              matchLabels = {
                                "app.kubernetes.io/instance"        = local.cluster_name
                                "app.kubernetes.io/managed-by"      = "kubeblocks"
                                "apps.kubeblocks.io/component-name" = "redis-sentinel"
                              }
                            }
                            topologyKey = "kubernetes.io/hostname"
                          }
                        }
                      ]
                    }
                  }
                } : {},
                # Node selector (if provided)
                length(local.node_selector) > 0 ? {
                  nodeSelector = local.node_selector
                } : {},
                # Tolerations - dynamic from node pool taints
                {
                  tolerations = local.tolerations
                }
              )
            }
          ] : []
        )
      } : {},
      local.backup_schedule_enabled ? {
        backup = {
          enabled         = local.backup_enabled
          retentionPeriod = local.backup_retention_period
          method          = local.backup_method
          cronExpression  = local.backup_cron_expression
        }
      } : {}
    )
  }

  advanced_config = {
    wait            = true
    timeout         = local.restore_enabled ? 3600 : 2700 # 60 mins if restore, else 45 mins
    cleanup_on_fail = true
    max_history     = 3
  }
}

# Read-Only Service (only for replication mode with Sentinel)
resource "kubernetes_service" "redis_read" {
  count = local.create_read_service ? 1 : 0

  metadata {
    name      = "${local.cluster_name}-redis-redis-read"
    namespace = local.namespace

    labels = {
      "app.kubernetes.io/instance"        = local.cluster_name
      "app.kubernetes.io/managed-by"      = "kubeblocks"
      "apps.kubeblocks.io/component-name" = "redis"
      "facets.io/created-by"              = "terraform"
    }
  }

  spec {
    type = "ClusterIP"

    # Target only secondary (read-only) replicas
    selector = {
      "app.kubernetes.io/instance"        = local.cluster_name
      "app.kubernetes.io/managed-by"      = "kubeblocks"
      "apps.kubeblocks.io/component-name" = "redis"
      "kubeblocks.io/role"                = "secondary"
    }

    port {
      name        = "tcp-redis"
      port        = 6379
      protocol    = "TCP"
      target_port = 6379
    }

    session_affinity = "None"
  }

  depends_on = [
    module.redis_cluster
  ]
}



# Wait for KubeBlocks to create and populate the connection secret
resource "time_sleep" "wait_for_credentials" {
  depends_on = [module.redis_cluster]

  create_duration = local.restore_enabled ? "180s" : "60s"
  triggers = {
    cluster_name    = local.cluster_name
    namespace       = local.namespace
    restore_enabled = local.restore_enabled
  }
}

# Data Source: Connection Credentials Secret
# KubeBlocks creates account secrets with pattern:
# - redis-cluster mode: {cluster-name}-shard-{random}-account-default (per shard)
# - replication mode: {cluster-name}-redis-account-default
# - standalone mode: {cluster-name}-redis-account-default

# Discover secrets based on mode
data "kubernetes_resources" "redis_secrets" {
  api_version    = "v1"
  kind           = "Secret"
  namespace      = local.namespace
  label_selector = "app.kubernetes.io/instance=${local.cluster_name},apps.kubeblocks.io/system-account=default"

  depends_on = [time_sleep.wait_for_credentials]
}

# For redis-cluster mode: fetch using discovered shard secret name
data "kubernetes_secret" "redis_cluster_credentials" {
  count = local.mode == "redis-cluster" ? 1 : 0

  metadata {
    name      = try(data.kubernetes_resources.redis_secrets.objects[0].metadata.name, "${local.cluster_name}-shard-account-default")
    namespace = local.namespace
  }

  depends_on = [data.kubernetes_resources.redis_secrets]
}

# For standalone/replication modes: use predictable secret name
data "kubernetes_secret" "redis_credentials" {
  count = local.mode != "redis-cluster" ? 1 : 0

  metadata {
    name      = "${local.cluster_name}-redis-account-default"
    namespace = local.namespace
  }

  depends_on = [time_sleep.wait_for_credentials]
}

# Data Source: Primary Service
# KubeBlocks auto-creates this service with format: {clusterName}-{componentName}-{serviceName}, *-redis-redis is the consistent pattern.
data "kubernetes_service" "redis_primary" {
  metadata {
    name      = "${local.cluster_name}-redis-redis"
    namespace = local.namespace
  }

  depends_on = [module.redis_cluster]
}

resource "time_sleep" "wait_for_restore" {
  count = local.restore_enabled ? 1 : 0

  depends_on = [module.redis_cluster]

  # Restore can take significant time depending on backup size
  # Initial wait before checking cluster status
  create_duration = "120s"

  triggers = {
    cluster_name    = local.cluster_name
    backup_name     = local.restore_backup_name
    restore_enabled = local.restore_enabled
  }
}

# Data Source: Check Cluster Status for Restore Completion
# KubeBlocks sets cluster phase to "Running" when restore is complete
data "kubernetes_resource" "cluster_status" {
  count = local.restore_enabled ? 1 : 0

  api_version = "apps.kubeblocks.io/v1"
  kind        = "Cluster"

  metadata {
    name      = local.cluster_name
    namespace = local.namespace
  }

  depends_on = [
    time_sleep.wait_for_restore[0]
  ]
}

# Volume Expansion
# KubeBlocks v1.0.1+ automatically handles volume expansion when you update
# the storage size in the Cluster spec above. No separate OpsRequest needed.
# When storage size increases, KubeBlocks will automatically:
# 1. Detect the change in volumeClaimTemplates
# 2. Create an OpsRequest internally
# 3. Expand the PVCs gracefully
#
# To expand storage: simply update var.instance.spec.storage.size and apply
