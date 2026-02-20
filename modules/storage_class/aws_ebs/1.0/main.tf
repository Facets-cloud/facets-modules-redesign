# Create StorageClass for AWS EBS volumes with CSI driver
resource "kubernetes_storage_class_v1" "storage_class" {
  metadata {
    name = var.instance.spec.name
    annotations = var.instance.spec.is_default ? {
      "storageclass.kubernetes.io/is-default-class" = "true"
    } : {}
    labels = merge(
      var.environment.cloud_tags,
      {
        "facets.cloud/instance-name" = var.instance_name
        "facets.cloud/environment"   = var.environment.name
      }
    )
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy        = var.instance.spec.reclaim_policy
  volume_binding_mode   = var.instance.spec.volume_binding_mode
  allow_volume_expansion = var.instance.spec.allow_volume_expansion

  # Build parameters dynamically based on volume type
  parameters = merge(
    {
      type      = var.instance.spec.volume_type
      encrypted = tostring(var.instance.spec.encrypted)
    },
    # Add iops for io1/io2 volumes if specified
    var.instance.spec.iops != null && contains(["io1", "io2"], var.instance.spec.volume_type) ? {
      iops = tostring(var.instance.spec.iops)
    } : {},
    # Add throughput for gp3 volumes if specified
    var.instance.spec.throughput != null && var.instance.spec.volume_type == "gp3" ? {
      throughput = tostring(var.instance.spec.throughput)
    } : {}
  )
}
