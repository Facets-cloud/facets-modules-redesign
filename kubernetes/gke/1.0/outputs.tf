locals {
  output_attributes = {
    cluster_id                = google_container_cluster.primary.id
    cluster_name              = google_container_cluster.primary.name
    cluster_endpoint          = google_container_cluster.primary.endpoint
    cluster_location          = google_container_cluster.primary.location
    cluster_ca_certificate    = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
    client_certificate        = sensitive(base64decode(google_container_cluster.primary.master_auth[0].client_certificate))
    client_key                = sensitive(base64decode(google_container_cluster.primary.master_auth[0].client_key))
    project_id                = local.project_id
    network                   = local.network
    subnetwork                = local.subnetwork
    release_channel           = local.release_channel
    node_pool_service_account = google_service_account.node_pool.email
    secrets                   = ["client_certificate", "client_key"]
  }
  output_interfaces = {
    kubernetes = {
      host                   = google_container_cluster.primary.endpoint
      client_key             = base64decode(google_container_cluster.primary.master_auth[0].client_key)
      client_certificate     = base64decode(google_container_cluster.primary.master_auth[0].client_certificate)
      cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
      secrets                = ["client_key", "client_certificate", "cluster_ca_certificate"]
    }
  }
}
