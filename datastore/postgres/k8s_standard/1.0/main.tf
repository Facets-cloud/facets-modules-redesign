# PostgreSQL Cluster Module - KubeBlocks v0.9.5
# Creates and manages PostgreSQL database clusters using KubeBlocks operator
# REQUIRES: KubeBlocks operator must be deployed first (CRDs must exist)

# Local variables for cleaner code
locals {
  cluster_name = var.instance.spec.cluster_name
  namespace = try(var.instance.spec.namespace_override, "") != "" ? var.instance.spec.namespace_override : var.environment.namespace
  replicas     = var.instance.spec.mode == "standalone" ? 1 : lookup(var.instance.spec, "replicas", 2)

  # HA settings
  ha_enabled               = var.instance.spec.mode == "replication"
  enable_pod_anti_affinity = local.ha_enabled && lookup(lookup(var.instance.spec, "high_availability", {}), "enable_pod_anti_affinity", true)
  anti_affinity_type       = local.ha_enabled ? lookup(lookup(var.instance.spec, "high_availability", {}), "anti_affinity_type", "Preferred") : "Preferred"
  create_read_service      = local.ha_enabled && lookup(lookup(var.instance.spec, "high_availability", {}), "create_read_service", true)

  # Backup settings - mapped to ClusterBackup API
  backup_config = lookup(var.instance.spec, "backup", {})

  # Check if selected backup method requires BackupRepo
  # volume-snapshot uses AWS EBS snapshots directly (no BackupRepo needed)
  # basebackup, wal-g methods need BackupRepo for storing backup files
  backup_method_needs_repo = contains(["basebackup"], local.backup_method)

  # Ensure boolean types
  backup_enabled     = try(lookup(local.backup_config, "enabled", false), false) == true
  
  ##create_backup_repo = local.backup_enabled && try(lookup(local.backup_config, "create_backup_repo", true), true) == true

  # BackupRepo creation logic
  # Only create if:
  # 1. Backup is enabled
  # 2. Backup method requires repo (not volume-snapshot)
  # 3. User wants to create new repo (not use existing shared repo)
  create_backup_repo = (local.backup_enabled && local.backup_method_needs_repo && try(lookup(local.backup_config, "create_backup_repo", true), true) == true)

  # BackupRepo name - cluster-scoped, must be unique across cluster
  backup_repo_name = local.backup_enabled && local.backup_method_needs_repo ? (
    local.create_backup_repo
    ? "${local.cluster_name}-backup-repo"                          # Auto-generated name for self-managed
    : try(lookup(local.backup_config, "backup_repo_name", ""), "") # User-provided shared repo name
  ) : ""

  backup_repo_storage       = try(lookup(local.backup_config, "backup_repo_storage_size", "20Gi"), "20Gi")
  backup_repo_storage_class = try(lookup(local.backup_config, "backup_repo_storage_class", ""), "")

  # Backup schedule settings (for Cluster.spec.backup)
  backup_schedule_enabled = local.backup_enabled && try(lookup(local.backup_config, "enable_schedule", false), false) == true
  backup_cron_expression  = try(lookup(local.backup_config, "schedule_cron", "0 2 * * *"), "0 2 * * *")
  backup_retention_period = try(lookup(local.backup_config, "retention_period", "7d"), "7d")

  # Backup method - determines if BackupRepo is needed (For volume-snapshot, we don't need BackupRepo)
  backup_method           = try(lookup(local.backup_config, "backup_method", "volume-snapshot"), "volume-snapshot")

  # PITR (Point-in-Time Recovery) settings
  pitr_enabled = local.backup_enabled && try(lookup(local.backup_config, "pitr_enabled", false), false) == true

  # Restore configuration - annotation-based restore from backup
  restore_config = lookup(var.instance.spec, "restore", {})
  restore_enabled = lookup(local.restore_config, "enabled", false) == true

  # Restore source details
  # Backup naming pattern from KubeBlocks:
  # - Scheduled backups: {cluster-name}-{backup-policy-name}-{timestamp}
  # - Manual backups: {backup-name} (user-provided)
  # - Volume-snapshot backups: {cluster-name}-backup-{timestamp}
  restore_backup_name = lookup(local.restore_config, "backup_name", "")

  # PITR (Point-in-Time Recovery) configuration
  # Requires continuous WAL archiving to be enabled in source cluster
  # Format: RFC3339 timestamp (e.g., "2025-01-25T10:30:00Z")
  restore_pitr_enabled = local.restore_enabled && try(lookup(local.restore_config, "pitr_enabled", false), false) == true
  restore_pitr_timestamp = try(lookup(local.restore_config, "pitr_timestamp", ""), "")

  # Component definition
  component_def_ref   = "postgresql"
  cluster_version_ref = "postgresql-${var.instance.spec.postgres_version}"

}

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

# BackupRepo - PVC-based backup repository
# Using any-k8s-resource module to avoid plan-time CRD validation
# Only created when:
# 1. Backup is enabled
# 2. Backup method requires repo (basebackup - NOT volume-snapshot)
# 3. User wants to create new repo (not use existing shared repo)

module "backup_repo" {
  count  = local.create_backup_repo ? 1 : 0
  source = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"

  name      = local.backup_repo_name
  namespace = local.namespace

  # Create implicit dependency on operator by including release_id in release name
  release_name = "backuprepo-${local.backup_repo_name}-${substr(var.inputs.kubeblocks_operator.output_interfaces.output.release_id, 0, 8)}"

  # Explicit dependency on namespace ensures this is created AFTER namespace
  depends_on = [kubernetes_namespace.postgresql_cluster]

  data = {
    apiVersion = "dataprotection.kubeblocks.io/v1alpha1"
    kind       = "BackupRepo"

    metadata = {
      name = local.backup_repo_name
      annotations = {
        "kubeblocks.io/operator-release-id"            = var.inputs.kubeblocks_operator.output_interfaces.output.release_id
        "kubeblocks.io/operator-dependency-id"         = var.inputs.kubeblocks_operator.output_interfaces.output.dependency_id
      }
      labels = {
        "app.kubernetes.io/name"       = "postgresql-backup-repo"
        "app.kubernetes.io/instance"   = var.instance_name
        "app.kubernetes.io/managed-by" = "terraform"
      }
    }

    spec = merge(
      {
        storageProviderRef = "pvc"
        volumeCapacity     = local.backup_repo_storage
        pvReclaimPolicy    = "Retain"
        config = {
          mountOptions = ""
        }
      },
      local.backup_repo_storage_class != "" ? {
        config = {
          storageClassName = local.backup_repo_storage_class
          mountOptions     = ""
        }
      } : {}
    )
  }

  advanced_config = {
    wait            = true
    timeout         = 600 # 10 minutes
    cleanup_on_fail = true
    max_history     = 3
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
    apiVersion = "apps.kubeblocks.io/v1alpha1"
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
          postgresql = merge(
            {
              name = local.restore_backup_name
              namespace = local.namespace
            },
            local.restore_pitr_enabled && local.restore_pitr_timestamp != "" ? {
            restoreTime = local.restore_pitr_timestamp
            } : {}
          )
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
        clusterDefinitionRef = "postgresql"
        clusterVersionRef    = local.cluster_version_ref
        terminationPolicy    = var.instance.spec.termination_policy

        componentSpecs = [
          {
            name            = "postgresql"
            componentDefRef = local.component_def_ref
            serviceVersion  = var.instance.spec.postgres_version
            replicas        = local.replicas

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

            tolerations = [
              {
                key      = "kubernetes.azure.com/scalesetpriority"
                operator = "Equal"
                value    = "spot"
                effect   = "NoSchedule"
              }
            ]
          }
        ]
      },
      # Conditional: Pod anti-affinity for HA
      local.enable_pod_anti_affinity ? {
        affinity = {
          podAntiAffinity = local.anti_affinity_type
          topologyKeys    = ["kubernetes.io/hostname"]
        }
      } : {},
      # Conditional: Backup configuration (ClusterBackup API)
      local.backup_schedule_enabled ? {
        backup = {
          enabled         = true
          repoName        = local.backup_repo_name
          retentionPeriod = local.backup_retention_period
          method          = local.backup_method
          pitrEnabled     = local.pitr_enabled
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
    cluster_name = local.cluster_name
    namespace    = local.namespace
    restore_enabled = local.restore_enabled
  }
}

# Data Source: Connection Credentials Secret
# KubeBlocks auto-creates this secret with format: {cluster-name}-conn-credential
data "kubernetes_secret" "postgres_credentials" {
  metadata {
    name      = "${local.cluster_name}-conn-credential"
    namespace = local.namespace
  }

  depends_on = [time_sleep.wait_for_credentials]
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

  api_version = "apps.kubeblocks.io/v1alpha1"
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
