# main.tf - ECK Operator Helm Chart Deployment

module "eck_operator" {
  source = "github.com/Facets-cloud/facets-utility-modules//helm"
  
  name             = var.instance_name
  namespace        = local.namespace
  create_namespace = local.create_namespace
  
  repository = local.repository
  chart      = local.chart_name
  version    = local.chart_version
  
  values = [yamlencode(local.final_values)]
  
  advanced_config = {}
}