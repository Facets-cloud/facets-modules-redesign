locals {
  output_interfaces = {}
  output_attributes = {
    release_name       = join(",", sort([for r in helm_release.r : r.name]))
    resource_name      = join(",", sort([for r in helm_release.r : r.name]))
    resource_namespace = join(",", distinct([for r in helm_release.r : r.namespace]))
  }
}
