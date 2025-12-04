# PostgreSQL Cluster Module - KubeBlocks v1.0.1
# Creates and manages PostgreSQL database clusters using KubeBlocks operator
# REQUIRES: KubeBlocks operator must be deployed first (CRDs must exist)

# Kubernetes Namespace for PostgreSQL Cluster
resource "kubernetes_namespace" "postgresql_cluster" {
  count = local.namespace == var.environment.namespace ? 0 : 1
  metadata {
    name = local.namespace

    annotations = {
      "kubeblocks.io/operator-release-id"    = var.inputs.kubeblocks_operator.output_interfaces.output.release_id
      "kubeblocks.io/operator-dependency-id" = var.inputs.kubeblocks_operator.output_interfaces.output.dependency_id
    }

    labels = merge(
      {
        "app.kubernetes.io/name"       = "postgresql-cluster"
        "app.kubernetes.io/instance"   = var.instance_name
        "app.kubernetes.io/managed-by" = "terraform"
      },
      var.environment.cloud_tags
    )
  }

  # Wait for resources to be deleted before namespace deletion completes
  timeouts {
    delete = "5m"
  }

  # If namespace already exists, don't fail - just import it
  lifecycle {
    ignore_changes = [
      metadata[0].labels,
      metadata[0].annotations
    ]
  }
}


# PostgreSQL Cluster with Embedded Backup Configuration
# Using any-k8s-resource module to avoid plan-time CRD validation
# Backup is configured via spec.backup (ClusterBackup API)
module "postgresql_cluster" {
  source = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"

  name         = local.cluster_name
  namespace    = local.namespace
  release_name = "pgcluster-${local.cluster_name}-${substr(var.inputs.kubeblocks_operator.output_interfaces.output.release_id, 0, 8)}"

  depends_on = [
    kubernetes_namespace.postgresql_cluster
  ]

  data = {
    apiVersion = "apps.kubeblocks.io/v1"
    kind       = "Cluster"

    metadata = {
      name      = local.cluster_name
      namespace = local.namespace

      annotations = merge(
        {
          "kubeblocks.io/operator-release-id"    = var.inputs.kubeblocks_operator.output_interfaces.output.release_id
          "kubeblocks.io/operator-dependency-id" = var.inputs.kubeblocks_operator.output_interfaces.output.dependency_id
        },
        local.restore_enabled && local.restore_backup_name != "" ? {
          "kubeblocks.io/restore-from-backup" = jsonencode({
            postgresql = {
              name      = local.restore_backup_name
              namespace = local.namespace
            }
          })
        } : {}
      )

      labels = merge(
        {
          "app.kubernetes.io/name"       = "postgresql"
          "app.kubernetes.io/instance"   = var.instance_name
          "app.kubernetes.io/managed-by" = "terraform"
          "app.kubernetes.io/version"    = var.instance.spec.postgres_version
        },
        local.restore_enabled ? {
          "dataprotection.kubeblocks.io/restore-source" = local.restore_backup_name
        } : {},
        var.environment.cloud_tags
      )
    }

    spec = merge(
      {
        clusterDef        = "postgresql"
        topology          = local.topology
        terminationPolicy = var.instance.spec.termination_policy

        componentSpecs = [
          merge(
            {
              name           = "postgresql"
              componentDef   = local.component_def
              serviceVersion = local.postgres_version
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

            # schedulingPolicy (nodeSelector, nodeName, affinity, tolerations)
            {
              schedulingPolicy = merge(
                # Conditional: Pod anti-affinity for HA
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
                                "apps.kubeblocks.io/component-name" = "postgresql"
                              }
                            }
                            topologyKey = "kubernetes.io/hostname"
                          }
                        }
                      ]
                    }
                  }
                } : {},

                # Tolerations (always applied)
                {
                  tolerations = [
                    {
                      key      = "kubernetes.azure.com/scalesetpriority"
                      operator = "Equal"
                      value    = "spot"
                      effect   = "NoSchedule"
                    },
                    {
                      # allow running on the mongodb-tainted node
                      key      = "mongodb"
                      operator = "Equal"
                      value    = "true"
                      effect   = "NoSchedule"
                    },
                    {
                      # allow scheduling on the CriticalAddonsOnly node
                      key      = "CriticalAddonsOnly"
                      operator = "Exists"
                      effect   = "NoSchedule"
                    }
                  ]
                }
              )
            }
          )
        ]
      },

      # Conditional: Backup configuration (ClusterBackup API)
      local.backup_schedule_enabled ? {
        backup = {
          enabled         = true
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
resource "kubernetes_service" "postgres_read" {
  count = local.create_read_service ? 1 : 0

  metadata {
    name      = "${local.cluster_name}-postgresql-read"
    namespace = local.namespace

    labels = {
      "app.kubernetes.io/instance"        = local.cluster_name
      "app.kubernetes.io/managed-by"      = "kubeblocks"
      "apps.kubeblocks.io/component-name" = "postgresql"
      "facets.io/created-by"              = "terraform"
    }
  }

  spec {
    type = "ClusterIP"

    # Target only secondary (read-only) replicas
    selector = {
      "app.kubernetes.io/instance"        = local.cluster_name
      "app.kubernetes.io/managed-by"      = "kubeblocks"
      "apps.kubeblocks.io/component-name" = "postgresql"
      "kubeblocks.io/role"                = "secondary"
    }

    port {
      name        = "tcp-postgresql"
      port        = 5432
      protocol    = "TCP"
      target_port = "tcp-postgresql"
    }

    port {
      name        = "tcp-pgbouncer"
      port        = 6432
      protocol    = "TCP"
      target_port = "tcp-pgbouncer"
    }

    session_affinity = "None"
  }

  depends_on = [
    kubernetes_namespace.postgresql_cluster,
    module.postgresql_cluster
  ]
}



# Wait for KubeBlocks to create and populate the connection secret
resource "time_sleep" "wait_for_credentials" {
  depends_on = [module.postgresql_cluster]

  create_duration = local.restore_enabled ? "180s" : "60s"
  triggers = {
    cluster_name    = local.cluster_name
    namespace       = local.namespace
    restore_enabled = local.restore_enabled
  }
}

# Data Source: Connection Credentials Secret
# Discover all account secrets
data "kubernetes_resources" "postgres_secrets" {
  api_version    = "v1"
  kind           = "Secret"
  namespace      = local.namespace
  label_selector = "app.kubernetes.io/instance=${local.cluster_name},apps.kubeblocks.io/system-account=postgres"

  depends_on = [time_sleep.wait_for_credentials]
}

# Fetch the postgres account secret
data "kubernetes_secret" "postgres_credentials" {
  metadata {
    name      = try(data.kubernetes_resources.postgres_secrets.objects[0].metadata.name, "${local.cluster_name}-postgresql-account-postgres")
    namespace = local.namespace
  }

  depends_on = [data.kubernetes_resources.postgres_secrets]
}

# Data Source: Primary Service
# KubeBlocks auto-creates this service with format: {cluster-name}-postgresql
data "kubernetes_service" "postgres_primary" {
  metadata {
    name      = "${local.cluster_name}-postgresql"
    namespace = local.namespace
  }

  depends_on = [module.postgresql_cluster]
}

resource "time_sleep" "wait_for_restore" {
  count = local.restore_enabled ? 1 : 0

  depends_on = [module.postgresql_cluster]

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
