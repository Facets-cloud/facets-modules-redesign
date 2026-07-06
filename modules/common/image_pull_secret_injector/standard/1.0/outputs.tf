locals {
  output_interfaces = {}
  output_attributes = {
    release_name      = helm_release.image-pull-secret-injector.name
    release_namespace = helm_release.image-pull-secret-injector.namespace
    chart_version     = helm_release.image-pull-secret-injector.version
  }
}