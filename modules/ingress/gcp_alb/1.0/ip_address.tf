# Global static IP address for the load balancer
resource "google_compute_global_address" "lb" {
  count = lookup(local.advanced_config, "ip_address_name", null) == null ? 1 : 0

  name         = "${local.name}-ip"
  project      = local.project_id
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
  labels       = local.labels
}

# Data source for existing IP address if provided
data "google_compute_global_address" "existing" {
  count = lookup(local.advanced_config, "ip_address_name", null) != null ? 1 : 0

  name    = local.advanced_config.ip_address_name
  project = local.project_id
}

locals {
  lb_ip_address = lookup(local.advanced_config, "ip_address_name", null) != null ? data.google_compute_global_address.existing[0].address : google_compute_global_address.lb[0].address
  lb_ip_name    = lookup(local.advanced_config, "ip_address_name", null) != null ? data.google_compute_global_address.existing[0].name : google_compute_global_address.lb[0].name
}
