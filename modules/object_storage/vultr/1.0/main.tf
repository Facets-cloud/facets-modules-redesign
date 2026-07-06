# Vultr Object Storage Module
# Creates an S3-compatible object storage subscription and exposes its S3 endpoint
# and access credentials. Unlike AWS S3 / Linode buckets, a Vultr object storage
# subscription is a full S3 endpoint with its own keys; buckets are created against
# it via the S3 API by the consuming application.

module "name" {
  source        = "github.com/Facets-cloud/facets-utility-modules//name"
  environment   = var.environment
  limit         = 63
  resource_name = var.instance_name
  resource_type = "objstore"
}

locals {
  # Labels are normalized to lowercase, DNS-compatible strings.
  store_label = lower(replace(module.name.name, "_", "-"))
}

# Resolve the object storage cluster by its unique hostname. Vultr exposes
# multiple object storage clusters per region (e.g. ewr -> ewr1, ewr2), so a
# region filter is ambiguous and the data source errors on >1 match. The
# hostname uniquely identifies a single cluster.
data "vultr_object_storage_cluster" "selected" {
  filter {
    name   = "hostname"
    values = [var.instance.spec.cluster_hostname]
  }
}

resource "vultr_object_storage" "store" {
  cluster_id = data.vultr_object_storage_cluster.selected.id
  tier_id    = var.instance.spec.tier_id
  label      = local.store_label
}
