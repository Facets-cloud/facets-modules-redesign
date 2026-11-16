# Define your locals here
locals {
  spec               = lookup(var.instance, "spec", {})
  namespace          = var.environment.namespace
  volume_size        = lookup(lookup(local.spec, "size", {}), "volume", "5Gi")
  storage_class_name = lookup(local.spec, "storage_class_name", null)
  access_modes       = lookup(local.spec, "access_modes", ["ReadWriteOnce"])
  name               = "${module.name.name}-pvc"
}
