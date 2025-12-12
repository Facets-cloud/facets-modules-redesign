locals {
  output_attributes = {
    version        = var.instance.spec.version
    crds_count     = local.crds_count
    release_id     = random_uuid.release_id.result
  }
  output_interfaces = {}
}