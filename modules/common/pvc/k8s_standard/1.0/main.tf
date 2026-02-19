# Define your terraform resources here

module "name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  is_k8s          = true
  globally_unique = true
  resource_type   = "pvc"
  resource_name   = var.instance_name
  environment     = var.environment
  limit           = 20
}

module "pvc" {
  source             = "github.com/Facets-cloud/facets-utility-modules//pvc"
  name               = local.name
  namespace          = local.namespace
  access_modes       = local.access_modes
  volume_size        = local.volume_size
  provisioned_for    = module.name.name
  instance_name      = lookup(var.instance_name, "name", module.name.name)
  kind               = "pvc"
  cloud_tags         = var.environment.cloud_tags
  storage_class_name = local.storage_class_name
}
