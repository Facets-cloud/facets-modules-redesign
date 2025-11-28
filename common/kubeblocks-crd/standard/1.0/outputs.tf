locals {
  output_attributes = {
    version        = var.instance.spec.version
    crds_count     = local.crds_count
    crds_installed = "true"
  }
  output_interfaces = {
    output = {
      release_id    = random_uuid.release_id.result
      dependency_id = random_uuid.dependency_id.result
      ready         = "true"
    }
  }
}