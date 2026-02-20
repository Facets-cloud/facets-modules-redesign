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
  reclaim_policy         = lookup(var.instance.spec, "reclaim_policy", "Delete")
  volume_binding_mode    = lookup(var.instance.spec, "volume_binding_mode", "WaitForFirstConsumer")
  allow_volume_expansion = lookup(var.instance.spec, "allow_volume_expansion", true)

  # Build parameters dynamically based on volume type
  parameters = merge(
    {
      type      = var.instance.spec.volume_type
      encrypted = tostring(lookup(var.instance.spec, "encrypted", true))
    },
    # Add iops for io1/io2 volumes if specified
    try(var.instance.spec.iops, null) != null && contains(["io1", "io2"], var.instance.spec.volume_type) ? {
      iops = tostring(var.instance.spec.iops)
    } : {},
    # Add throughput for gp3 volumes if specified
    try(var.instance.spec.throughput, null) != null && var.instance.spec.volume_type == "gp3" ? {
      throughput = tostring(var.instance.spec.throughput)
    } : {}
  )
}
