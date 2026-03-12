# Instance name — GCP allows up to 63 chars for compute resources
module "name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 50
  resource_name   = var.instance_name
  resource_type   = "vm"
  globally_unique = false
}

# Service account name — GCP enforces a 30-char hard limit on account IDs
module "sa_name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 30
  resource_name   = var.instance_name
  resource_type   = "sa"
  globally_unique = false
}

locals {
  vm_name = replace(module.name.name, "_", "-")
  sa_name = replace(module.sa_name.name, "_", "-")
}
