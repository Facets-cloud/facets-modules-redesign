locals {
  output_interfaces = {}
  output_attributes = {
    resource_name = join(",", sort(concat(
      [for r in helm_release.single : r.name],
      [for r in helm_release.multi : r.name],
    )))
    resource_namespace = ""
  }
}
