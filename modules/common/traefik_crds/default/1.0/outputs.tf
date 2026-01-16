locals {
  output_attributes = {
    helm_release_name    = helm_release.traefik_crds.name
    helm_release_version = helm_release.traefik_crds.version
    namespace            = helm_release.traefik_crds.namespace
    crds_installed       = true
  }
  output_interfaces = {}
}

