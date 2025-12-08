# main.tf - ECK Operator Helm Chart Deployment

resource "helm_release" "eck_operator" {
  name             = var.instance_name
  repository       = local.repository
  chart            = local.chart_name
  version          = local.chart_version
  namespace        = local.namespace
  create_namespace = local.create_namespace

  values = [
    yamlencode(local.final_values)
  ]

  # Wait for the operator to be deployed before marking as complete
  wait          = true
  wait_for_jobs = true
  timeout       = 600

  # Cleanup on failure
  atomic          = true
  cleanup_on_fail = true
}