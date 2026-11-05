locals {
  output_interfaces = {}
  output_attributes = {
    release_name = helm_release.main.name
  }
}
