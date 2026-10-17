# Create PVC for Prometheus
module "prometheus-pvc" {
  count           = local.create_pvcs ? 1 : 0
  source          = "./pvc_module"
  name            = local.prometheus_pvc_name
  namespace       = local.namespace
  access_modes    = ["ReadWriteOnce"]
  volume_size     = lookup(local.prometheusSpec.size, "volume", "100Gi")
  provisioned_for = "${local.helm_name}-0"
  instance_name   = var.instance_name
  kind            = "prometheus"
  cloud_tags      = var.environment.cloud_tags
}

# Create PVC for Alertmanager
module "alertmanager-pvc" {
  count           = local.create_pvcs ? 1 : 0
  source          = "./pvc_module"
  name            = local.alertmanager_pvc_name
  namespace       = local.namespace
  access_modes    = ["ReadWriteOnce"]
  volume_size     = lookup(local.alertmanagerSpec.size, "volume", "10Gi")
  provisioned_for = "${local.helm_name}-alertmanager-0"
  instance_name   = var.instance_name
  kind            = "prometheus"
  cloud_tags      = var.environment.cloud_tags
}
