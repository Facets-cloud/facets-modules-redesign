# Output contract: @facets/argo_service
#
# Exposes the ApplicationSet coordinates and the chart source it deploys, so a
# downstream resource can reference the app without restating the chart
# coordinates, and so a CI pipeline can target the same chart path.

locals {
  output_interfaces = {}

  output_attributes = {
    applicationset_name = local.service_name
    application_name    = local.service_name
    argocd_project      = lookup(local.spec, "argocd_project", "default")
    argocd_namespace    = local.argocd_namespace
    resource_namespace  = local.namespace
    # Retained from v1 so existing consumers of resource_name keep working.
    resource_name   = local.service_name
    service_name    = local.service_name
    release_name    = local.release_name
    chart_repo_url  = local.chart.repo_url
    chart_path      = local.chart.path
    target_revision = lookup(local.chart, "revision", "develop")
    values_path     = local.chart.values_path
  }
}
