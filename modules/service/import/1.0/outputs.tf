locals {
  output_interfaces = {}
  output_attributes = {
    resource_name = join(",", sort([for r in helm_release.app_chart : r.name]))
    resource_type = "service"
    namespace     = "default"
  }
}
