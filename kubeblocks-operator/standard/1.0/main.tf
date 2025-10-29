# KubeBlocks Operator Installation
# This module installs KubeBlocks core operator on Kubernetes cluster
#
# IMPORTANT: Manual Cleanup Required Before Destroy
# ================================================
# When running `terraform destroy`, you MUST manually clean up KubeBlocks resources first.
# The operator creates cluster-scoped Addon CRs that are NOT managed by Terraform/Helm,
# and these will BLOCK namespace deletion, causing destroy to hang indefinitely.
#
# Required Manual Cleanup Steps:
# -------------------------------
# Run these commands BEFORE `terraform destroy`:
#
#   # 1. Delete Addon CRs (19 cluster-scoped resources created by operator webhook)
#   kubectl delete addons.extensions.kubeblocks.io --all --force --grace-period=0
#
#   # 2. Patch leftover ConfigMaps (kept by Helm resource policy)
#   kubectl get configmaps -n kb-system -l app.kubernetes.io/managed-by=Helm -o name | xargs -I {} kubectl patch {} -n kb-system -p '{"metadata":{"finalizers":[]}}' --type=merge
#
#   # 3. Patch CRD finalizers (prevents stuck CRD deletion)
#   kubectl get crd -l app.kubernetes.io/name=kubeblocks -o name | xargs -I {} kubectl patch {} --type merge -p '{"metadata":{"finalizers":[]}}'

# Fetch CRDs from GitHub
data "http" "kubeblocks_crds" {
  url = "https://github.com/apecloud/kubeblocks/releases/download/v${var.instance.spec.version}/kubeblocks_crds.yaml"
}

# Split the multi-document YAML into individual CRDs
locals {
  crds_yaml = data.http.kubeblocks_crds.response_body
  # Split by document separator and filter out empty documents
  crd_documents = [for doc in split("\n---\n", local.crds_yaml) : trimspace(doc) if trimspace(doc) != ""]
}

# Apply each CRD using kubernetes_manifest
resource "kubernetes_manifest" "kubeblocks_crds" {
  for_each = { for idx, doc in local.crd_documents : idx => doc }

  manifest = yamldecode(each.value)

  field_manager {
    name            = "terraform"
    force_conflicts = true
  }

  wait {
    condition {
      type   = "Established"
      status = "True"
    }
  }

  # Handle computed fields that may change outside Terraform's control
  # This prevents Terraform from trying to manage finalizers and status
  computed_fields = [
    "metadata.finalizers",
    "metadata.generation",
    "metadata.resourceVersion",
    "status"
  ]
}

# Kubernetes Namespace for KubeBlocks
resource "kubernetes_namespace" "kubeblocks" {
  metadata {
    name = var.instance.spec.namespace

    labels = merge(
      {
        "app.kubernetes.io/name"       = "kubeblocks"
        "app.kubernetes.io/instance"   = var.instance_name
        "app.kubernetes.io/version"    = var.instance.spec.version
        "app.kubernetes.io/managed-by" = "terraform"
      },
      var.environment.cloud_tags
    )
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      metadata[0].labels
    ]
  }

  # Wait for namespace deletion to complete
  # This ensures Terraform waits for all resources to be cleaned up
  timeouts {
    delete = "10m"
  }
}

# KubeBlocks Helm Release
# CRDs are automatically installed via kubernetes_manifest resources above
resource "helm_release" "kubeblocks" {
  name       = "kubeblocks"
  repository = "https://apecloud.github.io/helm-charts"
  chart      = "kubeblocks"
  version    = var.instance.spec.version
  namespace  = kubernetes_namespace.kubeblocks.metadata[0].name

  create_namespace = false
  wait             = true
  wait_for_jobs    = true
  timeout          = 600 # 10 minutes
  max_history      = 3

  # Skip CRDs - they're already installed via kubernetes_manifest resources
  skip_crds = true

  # Allow resource replacement during upgrades
  replace = true

  values = [
    yamlencode(merge(
      {
        # Addon controller is disabled - addons are installed via database_addons configuration
        # This prevents webhook-created Addon CRs that would block namespace deletion
        addonController = {
          enabled = false
        }

        # Prevent retention of addon resources on uninstall
        # This ensures Helm deletes addon resources during destroy
        keepAddons = false

        # Remove global resources on uninstall
        # This prevents orphaned cluster-scoped resources
        keepGlobalResources = false

        dataProtection = {
          enabled                = lookup(var.instance.spec.data_protection, "enabled", true)
          enableBackupEncryption = lookup(var.instance.spec.data_protection, "backup_encryption", false)
          tolerations = [
            {
              key      = "kubernetes.azure.com/scalesetpriority"
              operator = "Equal"
              value    = "spot"
              effect   = "NoSchedule"
            }
          ]
        }
        featureGates = {
          inPlacePodVerticalScaling = {
            enabled = lookup(lookup(var.instance.spec, "feature_gates", {}), "in_place_pod_vertical_scaling", false)
          }
        }
        resources = {
          limits = {
            cpu    = lookup(lookup(var.instance.spec, "controller_resources", {}), "cpu_limit", "1000m")
            memory = lookup(lookup(var.instance.spec, "controller_resources", {}), "memory_limit", "1Gi")
          }
          requests = {
            cpu    = lookup(lookup(var.instance.spec, "controller_resources", {}), "cpu_request", "500m")
            memory = lookup(lookup(var.instance.spec, "controller_resources", {}), "memory_request", "512Mi")
          }
        }
        image = {
          pullPolicy = "IfNotPresent"
        }
        # Add tolerations to allow scheduling on spot instances and other tainted nodes
        tolerations = [
          {
            key      = "kubernetes.azure.com/scalesetpriority"
            operator = "Equal"
            value    = "spot"
            effect   = "NoSchedule"
          }
        ]
      },
      # Only include backupRepo configuration if create is explicitly set to true
      lookup(lookup(var.instance.spec, "backup_repository", {}), "create", false) == true ? {
        backupRepo = {
          create          = true
          default         = true
          accessMethod    = "Tool"
          storageProvider = var.instance.spec.backup_repository.storage_provider
          pvReclaimPolicy = "Retain"
          volumeCapacity  = var.instance.spec.backup_repository.volume_capacity
        }
      } : {}
    ))
  ]

  # Ensure namespace and CRDs exist before installing the operator
  depends_on = [
    kubernetes_namespace.kubeblocks,
    kubernetes_manifest.kubeblocks_crds
  ]
}

# Database Addons Installation
# Install database addons as Terraform-managed Helm releases
# This ensures proper lifecycle management and clean teardown

locals {
  # Map of all available addons with their chart configurations
  addon_configs = {
    postgresql = {
      chart_name = "postgresql"
      version    = "0.9.5"
      repo       = "https://apecloud.github.io/helm-charts"
    }
    mysql = {
      chart_name = "mysql"
      version    = "0.9.3"
      repo       = "https://apecloud.github.io/helm-charts"
    }
    mongodb = {
      chart_name = "mongodb"
      version    = "0.9.3"
      repo       = "https://apecloud.github.io/helm-charts"
    }
    redis = {
      chart_name = "redis"
      version    = "0.9.7"
      repo       = "https://apecloud.github.io/helm-charts"
    }
    kafka = {
      chart_name = "kafka"
      version    = "0.9.1"
      repo       = "https://apecloud.github.io/helm-charts"
    }
  }

  # Filter only enabled addons
  enabled_addons = {
    for name, config in local.addon_configs :
    name => config
    if lookup(lookup(var.instance.spec, "database_addons", {}), name, false) == true
  }
}

# Install each enabled addon as a separate Helm release
resource "helm_release" "database_addons" {
  for_each = local.enabled_addons

  name       = "kb-addon-${each.value.chart_name}"
  repository = each.value.repo
  chart      = each.value.chart_name
  version    = each.value.version
  namespace  = kubernetes_namespace.kubeblocks.metadata[0].name

  create_namespace = false
  wait             = true
  wait_for_jobs    = true
  timeout          = 600
  max_history      = 3

  # Addons should not install CRDs - operator already installed them
  skip_crds = true

  # Ensure operator is fully deployed before installing addons
  depends_on = [helm_release.kubeblocks]
}
