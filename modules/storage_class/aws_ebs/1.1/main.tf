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

  # ADOPTION: older clusters use the in-tree provisioner `kubernetes.io/aws-ebs`. `provisioner` is
  # IMMUTABLE, so adopting such a StorageClass without this override forces a destroy+recreate.
  storage_provisioner    = lookup(var.instance.spec, "storage_provisioner", "ebs.csi.aws.com")
  reclaim_policy         = lookup(var.instance.spec, "reclaim_policy", "Delete")
  volume_binding_mode    = lookup(var.instance.spec, "volume_binding_mode", "WaitForFirstConsumer")
  allow_volume_expansion = lookup(var.instance.spec, "allow_volume_expansion", true)

  # Build parameters dynamically.
  # ADOPTION NOTE: `parameters` is IMMUTABLE on a StorageClass, so the rendered map must match live
  # EXACTLY. Every optional key is therefore emitted ONLY when explicitly set — previously `encrypted`
  # was always emitted and `throughput` was force-defaulted to 125 for gp3, either of which forces a
  # destroy+recreate when adopting a live class that lacks them.
  parameters = merge(
    { type = var.instance.spec.volume_type },
    lookup(var.instance.spec, "encrypted", null) != null ? { encrypted = tostring(lookup(var.instance.spec, "encrypted", null)) } : {},
    lookup(var.instance.spec, "fs_type", null) != null ? { fsType = tostring(lookup(var.instance.spec, "fs_type", null)) } : {},
    lookup(var.instance.spec, "iops", null) != null && contains(["io1", "io2"], var.instance.spec.volume_type) ? {
      iops = tostring(lookup(var.instance.spec, "iops", null))
    } : {},
    lookup(var.instance.spec, "throughput", null) != null ? {
      throughput = tostring(lookup(var.instance.spec, "throughput", null))
    } : {}
  )
}
