locals {
  output_attributes = {
    id               = google_network_connectivity_service_connection_policy.this.id
    name             = google_network_connectivity_service_connection_policy.this.name
    project_id       = local.project_id
    region           = local.region
    network          = local.network
    service_class    = google_network_connectivity_service_connection_policy.this.service_class
    connection_limit = lookup(var.instance.spec, "connection_limit", 4)
    subnetworks      = [local.private_subnet]
  }

  output_interfaces = {}
}
