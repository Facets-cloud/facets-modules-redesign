# Length-capped name via the //name module (RULE-024). spec.name wins so a consumer can mount a fixed ConfigMap name.
module "name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  resource_name   = var.instance_name
  resource_type   = "config-map"
  limit           = 253
  is_k8s          = true
  globally_unique = false
}

locals {
  name_override = trimspace(lookup(local.spec, "name", "") == null ? "" : lookup(local.spec, "name", ""))
  resource_name = local.name_override != "" ? local.name_override : module.name.name
}
