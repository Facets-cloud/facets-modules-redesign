# Resource naming — user-supplied spec.name wins; else the facets name module (env-scoped) fallback.
module "name" {
  source        = "github.com/Facets-cloud/facets-utility-modules//name"
  environment   = var.environment
  resource_name = var.instance_name
  resource_type = "eks"
  limit         = 63
}

locals {
  name_override = trimspace(try(local.spec.name, ""))
  resource_name = local.name_override != "" ? local.name_override : module.name.name
  # GKE names: <=40 chars, MUST start with a lowercase letter, then [a-z0-9-], no trailing hyphen.
  # The //name module can lead with the project-number digits (EKS tolerates it, GKE does not), so
  # construct a letter-first name: "gke-<instance>-<hash>" (<=32 here; the "-sys" node pool suffix fits 40).
  gke_cluster_name = local.name_override != "" ? substr(lower(local.name_override), 0, 36) : substr("gke-${replace(lower(var.instance_name), "_", "-")}-${substr(sha256(var.environment.unique_name), 0, 8)}", 0, 36)
}
