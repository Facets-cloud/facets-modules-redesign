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
  # Split by document separator and filter out empty documents
  crd_documents = [for doc in split("\n---\n", local.crds_yaml) : trimspace(doc) if trimspace(doc) != ""]
  crds_count    = length(local.crd_documents)
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

  lifecycle {
    prevent_destroy = false # Explicitly allow destruction (this is default)
  }

  timeouts {
    create = "10m"
    delete = "10m"
  }
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

# Generate dependency_id for Terraform-level dependency tracking
resource "random_uuid" "dependency_id" {
  keepers = {
    release_id = random_uuid.release_id.result
  }
  depends_on = [
    random_uuid.release_id
  ]
}
