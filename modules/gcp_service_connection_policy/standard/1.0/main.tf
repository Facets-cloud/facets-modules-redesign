terraform {
  required_version = ">= 1.0"
}

resource "google_network_connectivity_service_connection_policy" "this" {
  name          = local.policy_name
  project       = local.project_id
  location      = local.region
  service_class = lookup(var.instance.spec, "service_class", "gcp-memorystore")
  description   = lookup(var.instance.spec, "description", "Memorystore PSC service connection policy")
  network       = local.network
  labels        = local.labels

  psc_config {
    subnetworks = [local.private_subnet]
    limit       = lookup(var.instance.spec, "connection_limit", 4)
  }
}
