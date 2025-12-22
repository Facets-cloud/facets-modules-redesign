# KubeBlocks CRDs Installation
# This module installs ONLY the Custom Resource Definitions for KubeBlocks
# The CRDs are large (>5MB) and cannot be managed via Helm due to the 1MB storage limit
#
# IMPORTANT: This module must be deployed BEFORE kubeblocks-operator module
# The operator module will depend on this module's release_id for proper sequencing

# Fetch CRDs from GitHub
data "http" "kubeblocks_crds" {
  url = "https://github.com/apecloud/kubeblocks/releases/download/v${var.instance.spec.version}/kubeblocks_crds.yaml"
}

# Split the multi-document YAML into individual CRDs
locals {
  crds_yaml = data.http.kubeblocks_crds.response_body

  crd_documents = [for doc in split("\n---\n", local.crds_yaml) : yamldecode(doc) if trimspace(doc) != ""]

  # Key by CRD metadata.name (stable & unique)
  crds = {
    for crd in local.crd_documents :
    crd.metadata.name => crd
  }

  crds_count = length(local.crds)
}

# Apply each CRD using kubernetes_manifest
resource "kubernetes_manifest" "kubeblocks_crds" {
  for_each = local.crds

  # Mark manifest as sensitive to hide CRD content from plan output
  manifest = sensitive(each.value)

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
    "metadata.uid",
    "status"
  ]

  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      manifest,
      object
    ]
  }

  timeouts {
    create = "10m"
    delete = "10m"
  }
}

# Time sleep resource to ensure proper cleanup during destroy
# This gives extra time for any remaining custom resources to be deleted before CRDs are removed
resource "time_sleep" "wait_for_cleanup" {
  destroy_duration = "120s"


  # Provides a 120s buffer at the start of CRD module destruction
}

# Generate a unique release_id for dependency tracking
# This will be used by kubeblocks-operator module to ensure CRDs are installed first
resource "random_uuid" "release_id" {
  keepers = {
    version    = var.instance.spec.version
    crds_count = local.crds_count
  }
  depends_on = [
    kubernetes_manifest.kubeblocks_crds
  ]
}
