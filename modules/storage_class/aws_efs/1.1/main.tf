locals {
  spec          = lookup(var.instance, "spec", {})
  metadata_name = lookup(lookup(var.instance, "metadata", {}), "name", "")
  instance_name = length(local.metadata_name) > 0 ? local.metadata_name : var.instance_name
  sc_name       = lookup(local.spec, "name", local.instance_name)
}

resource "kubernetes_storage_class_v1" "efs_storage_class" {
  metadata {
    name = local.sc_name
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "false"
    }
    labels = merge(
      var.environment.cloud_tags,
      {
        "facets.cloud/instance-name" = var.instance_name
        "facets.cloud/environment"   = var.environment.name
      },
      # Only stamp the CSI release id when there IS one. When the driver is an EKS MANAGED ADDON the
      # module that owns it sets manage_helm_release=false, so helm_release_id is null and a null map
      # value would fail the apply.
      try(var.inputs.csi_driver.attributes.helm_release_id, null) != null ? {
        "facets.cloud/efs-csi-release-id" = var.inputs.csi_driver.attributes.helm_release_id
      } : {}
    )
  }

  storage_provisioner = "efs.csi.aws.com"
  mount_options = [
    "tls",
    "iam"
  ]
  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = var.inputs.aws_efs.attributes.file_system_id
    directoryPerms   = lookup(local.spec, "directory_permissions", "700")
  }
  reclaim_policy      = lookup(local.spec, "reclaim_policy", "Delete")
  volume_binding_mode = lookup(local.spec, "volume_binding_mode", "Immediate")
}
