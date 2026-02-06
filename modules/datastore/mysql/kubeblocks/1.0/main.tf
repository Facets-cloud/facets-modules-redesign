# MySQL Cluster Module - KubeBlocks v1.0.1
# Creates and manages MySQL database clusters using KubeBlocks operator
# REQUIRES: KubeBlocks operator must be deployed first (CRDs must exist)


# MySQL Cluster with Embedded Backup Configuration
# Using any-k8s-resource module to avoid plan-time CRD validation
# Backup is configured via spec.backup (ClusterBackup API)
module "mysql_cluster" {
  source = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"

  name         = local.cluster_name
  namespace    = local.namespace
  release_name = "mysql-${local.cluster_name}-${substr(var.inputs.kubeblocks_operator.attributes.release_id, 0, 8)}"

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
            mysql = {
              name      = local.restore_backup_name
              namespace = local.namespace
            }
          })
        } : {}
      )

      labels = merge(
        {
          "app.kubernetes.io/name"       = "mysql"
          "app.kubernetes.io/instance"   = var.instance_name
          "app.kubernetes.io/managed-by" = "terraform"
          "app.kubernetes.io/version"    = var.instance.spec.mysql_version
        },
        local.restore_enabled ? {
          "dataprotection.kubeblocks.io/restore-source" = local.restore_backup_name
        } : {},
        var.environment.cloud_tags
      )
    }

    spec = merge(
      {
        clusterDef        = "mysql"
        topology          = local.topology
        terminationPolicy = var.instance.spec.termination_policy

        componentSpecs = [
          merge(
            {
              name           = "mysql"
              componentDef   = local.component_def
              serviceVersion = local.mysql_version
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
            },

            # schedulingPolicy (nodeSelector, nodeName, affinity, tolerations)
            {
              schedulingPolicy = merge(
                # Pod anti-affinity for HA
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
                                "apps.kubeblocks.io/component-name" = "mysql"
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
        ]
      },

      # Conditional: Backup configuration (ClusterBackup API)
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

# Read-Only Service (only for replication mode)
resource "kubernetes_service" "mysql_read" {
  count = local.create_read_service ? 1 : 0

  metadata {
    name      = "${local.cluster_name}-mysql-read"
    namespace = local.namespace

    labels = {
      "app.kubernetes.io/instance"        = local.cluster_name
      "app.kubernetes.io/managed-by"      = "kubeblocks"
      "apps.kubeblocks.io/component-name" = "mysql"
      "facets.io/created-by"              = "terraform"
    }
  }

  spec {
    type = "ClusterIP"

    # Target only secondary (read-only) replicas
    selector = {
      "app.kubernetes.io/instance"        = local.cluster_name
      "app.kubernetes.io/managed-by"      = "kubeblocks"
      "apps.kubeblocks.io/component-name" = "mysql"
      "kubeblocks.io/role"                = "secondary"
    }

    port {
      name        = "tcp-mysql"
      port        = 3306
      protocol    = "TCP"
      target_port = "tcp-mysql"
    }

    session_affinity = "None"
  }

  depends_on = [
    module.mysql_cluster
  ]
}



# Wait for KubeBlocks to create and populate the connection secret
resource "time_sleep" "wait_for_credentials" {
  depends_on = [module.mysql_cluster]

  create_duration = local.restore_enabled ? "180s" : "60s"
  triggers = {
    cluster_name    = local.cluster_name
    namespace       = local.namespace
    restore_enabled = local.restore_enabled
  }
}

# Data Source: Connection Credentials Secret
# KubeBlocks creates account secrets with pattern: {cluster-name}-{component}-account-{role}
# For MySQL: {cluster-name}-mysql-account-root is the main application credential

# Discover all account secrets
data "kubernetes_resources" "mysql_secrets" {
  api_version    = "v1"
  kind           = "Secret"
  namespace      = local.namespace
  label_selector = "app.kubernetes.io/instance=${local.cluster_name},apps.kubeblocks.io/system-account=root"

  depends_on = [time_sleep.wait_for_credentials]
}

# Fetch the root account secret
data "kubernetes_secret" "mysql_credentials" {
  metadata {
    name      = try(data.kubernetes_resources.mysql_secrets.objects[0].metadata.name, "${local.cluster_name}-mysql-account-root")
    namespace = local.namespace
  }

  depends_on = [data.kubernetes_resources.mysql_secrets]
}

# Data Source: Primary Service
# KubeBlocks auto-creates this service with format: {cluster-name}-mysql
data "kubernetes_service" "mysql_primary" {
  metadata {
    name      = "${local.cluster_name}-mysql"
    namespace = local.namespace
  }

  depends_on = [module.mysql_cluster]
}

resource "time_sleep" "wait_for_restore" {
  count = local.restore_enabled ? 1 : 0

  depends_on = [module.mysql_cluster]

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
# KubeBlocks v0.9.5+ automatically handles volume expansion when you update
# the storage size in the Cluster spec above. No separate OpsRequest needed.
# When storage size increases, KubeBlocks will automatically:
# 1. Detect the change in volumeClaimTemplates
# 2. Create an OpsRequest internally
# 3. Expand the PVCs gracefully
#
# To expand storage: simply update var.instance.spec.storage.size and apply
