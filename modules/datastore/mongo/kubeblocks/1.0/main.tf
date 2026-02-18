# MongoDB Cluster Module - KubeBlocks v1.0.1
# Creates and manages MongoDB database clusters using KubeBlocks operator
# REQUIRES: KubeBlocks operator must be deployed first (CRDs must exist)

module "name" {
  source        = "github.com/Facets-cloud/facets-utility-modules//name"
  resource_name = var.instance_name
  resource_type = "mongodb"
  environment   = var.environment
  limit         = 63
  is_k8s        = true
}

# MongoDB Cluster with Embedded Backup Configuration
# Using any-k8s-resource module to avoid plan-time CRD validation
# Backup is configured via spec.backup (ClusterBackup API)
module "mongodb_cluster" {
  source = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"

  name         = local.cluster_name
  namespace    = local.namespace
  release_name = "mongocluster-${local.cluster_name}-${substr(var.inputs.kubeblocks_operator.attributes.release_id, 0, 8)}"


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
            mongodb = {
              name      = local.restore_backup_name
              namespace = local.namespace
            }
          })
        } : {}
      )

      labels = merge(
        {
          "app.kubernetes.io/name"       = "mongodb"
          "app.kubernetes.io/instance"   = var.instance_name
          "app.kubernetes.io/managed-by" = "terraform"
          "app.kubernetes.io/version"    = var.instance.spec.mongodb_version
        },
        local.restore_enabled ? {
          "dataprotection.kubeblocks.io/restore-source" = local.restore_backup_name
        } : {},
        var.environment.cloud_tags
      )
    }

    spec = merge(
      {
        clusterDef        = "mongodb"
        topology          = local.topology
        terminationPolicy = var.instance.spec.termination_policy

        componentSpecs = [
          merge(
            {
              name           = "mongodb"
              componentDef   = local.component_def
              serviceVersion = local.service_version
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
                # Pod anti-affinity for HA - soft anti-affinity prefers different nodes
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
                                "apps.kubeblocks.io/component-name" = "mongodb"
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

                # Tolerations (if provided)
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

# PodDisruptionBudget for MongoDB HA
# maxUnavailable=1 ensures only 1 pod can be disrupted at a time
# This maintains quorum during node maintenance/upgrades
resource "kubernetes_pod_disruption_budget_v1" "mongodb_pdb" {
  count = local.enable_pdb ? 1 : 0

  metadata {
    name      = "${local.cluster_name}-mongodb-pdb"
    namespace = local.namespace

    labels = merge(
      {
        "app.kubernetes.io/name"       = "mongodb"
        "app.kubernetes.io/instance"   = local.cluster_name
        "app.kubernetes.io/managed-by" = "terraform"
      },
      var.environment.cloud_tags
    )
  }

  spec {
    max_unavailable = "1"

    selector {
      match_labels = {
        "app.kubernetes.io/instance"        = local.cluster_name
        "app.kubernetes.io/managed-by"      = "kubeblocks"
        "apps.kubeblocks.io/component-name" = "mongodb"
      }
    }
  }

  depends_on = [module.mongodb_cluster]
}

# Wait for KubeBlocks to create and populate the connection secret
resource "time_sleep" "wait_for_credentials" {
  depends_on = [module.mongodb_cluster]

  create_duration = local.restore_enabled ? "180s" : "90s"
  triggers = {
    cluster_name    = local.cluster_name
    namespace       = local.namespace
    restore_enabled = local.restore_enabled
  }
}

# Data Source: Connection Credentials Secret
# Discover MongoDB account secrets
data "kubernetes_resources" "mongodb_secrets" {
  api_version    = "v1"
  kind           = "Secret"
  namespace      = local.namespace
  label_selector = "app.kubernetes.io/instance=${local.cluster_name},apps.kubeblocks.io/account-name=root"

  depends_on = [time_sleep.wait_for_credentials]
}

# Fetch the root account secret
data "kubernetes_secret" "mongodb_credentials" {
  metadata {
    name      = try(data.kubernetes_resources.mongodb_secrets.objects[0].metadata.name, "${local.cluster_name}-mongodb-account-root")
    namespace = local.namespace
  }

  depends_on = [data.kubernetes_resources.mongodb_secrets]
}

# Data Source: Primary Service
# KubeBlocks auto-creates this service with format: {cluster-name}-mongodb
data "kubernetes_service" "mongodb_primary" {
  metadata {
    name      = "${local.cluster_name}-mongodb"
    namespace = local.namespace
  }

  depends_on = [module.mongodb_cluster]
}

resource "time_sleep" "wait_for_restore" {
  count = local.restore_enabled ? 1 : 0

  depends_on = [module.mongodb_cluster]

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

module "external_access_ops" {
  for_each = local.external_access_config

  source = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"

  name         = "${local.cluster_name}-expose-${each.key}"
  namespace    = local.namespace
  release_name = "mongo-expose-${each.key}-${substr(var.inputs.kubeblocks_operator.attributes.release_id, 0, 8)}"

  depends_on = [
    module.mongodb_cluster
  ]

  data = {
    apiVersion = "operations.kubeblocks.io/v1alpha1"
    kind       = "OpsRequest"

    metadata = {
      name      = "${local.cluster_name}-expose-${each.key}"
      namespace = local.namespace

      labels = merge(
        {
          "app.kubernetes.io/name"       = "mongodb"
          "app.kubernetes.io/instance"   = var.instance_name
          "app.kubernetes.io/managed-by" = "terraform"
        },
        var.environment.cloud_tags
      )
    }

    spec = {
      clusterName = local.cluster_name

      expose = [
        {
          componentName = "mongodb"
          services = [
            {
              name         = each.key
              roleSelector = each.value.role
              serviceType  = "LoadBalancer"
              annotations  = each.value.annotations
            }
          ]
          switch = "Enable"
        }
      ]

      preConditionDeadlineSeconds = 0
      type                        = "Expose"
    }
  }

  advanced_config = {
    wait            = true
    timeout         = 600 # 10 minutes for LoadBalancer provisioning
    cleanup_on_fail = true
    max_history     = 3
  }
}

resource "time_sleep" "wait_for_external_access" {
  count = local.has_external_access ? 1 : 0

  depends_on = [
    module.external_access_ops
  ]

  # Initial wait before checking external service status
  create_duration = "60s"

  triggers = {
    cluster_name = local.cluster_name
  }
}

# Data source to fetch external service details after OpsRequest completes
data "kubernetes_service" "external_access" {
  for_each = local.has_external_access ? local.external_access_config : {}

  metadata {
    name      = "${local.cluster_name}-mongodb-${each.key}"
    namespace = local.namespace
  }

  depends_on = [
    module.external_access_ops,
    time_sleep.wait_for_external_access
  ]
}

# Volume Expansion
# KubeBlocks v1.0.1 automatically handles volume expansion when you update
# the storage size in the Cluster spec above. No separate OpsRequest needed.
# When storage size increases, KubeBlocks will automatically:
# 1. Detect the change in volumeClaimTemplates
# 2. Create an OpsRequest internally
# 3. Expand the PVCs gracefully
#
# To expand storage: simply update var.instance.spec.storage.size and apply
#
# Requirements:
# - Storage class must have ALLOWVOLUMEEXPANSION=true
# - Some cloud providers (e.g., Azure) may have VM-specific disk constraints
# - Check cluster status with: kubectl get cluster -n <namespace>
#   Status will show "Updating" during expansion
# - Verify PVC expansion: kubectl get pvc -n <namespace>

# External Access via OpsRequest
# Creates LoadBalancer services for external connectivity to MongoDB cluster