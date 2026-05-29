locals {
  # GKE exec-auth helper: runs the OAuth2 JWT-bearer flow in pure bash and
  # emits an ExecCredential. See gke-exec-auth.sh.tftpl for the script.
  exec_bash_command = templatefile(
    "${path.module}/gke-exec-auth.sh.tftpl",
    { credentials = local.credentials }
  )

  output_attributes = {
    # Cluster identification
    cluster_id       = google_container_cluster.primary.id
    cluster_name     = google_container_cluster.primary.name
    cluster_location = google_container_cluster.primary.location
    cluster_version  = google_container_cluster.primary.master_version
    cloud_provider   = "GCP"
    # Authentication - standard names matching EKS/AKS
    cluster_endpoint       = "https://${google_container_cluster.primary.endpoint}"
    cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
    kubernetes_provider_exec = {
      api_version = "client.authentication.k8s.io/v1"
      command     = "bash"
      args        = ["-c", local.exec_bash_command]
    }

    # Project and region details
    project_id = local.project_id
    region     = local.region

    # Network configuration
    network             = local.network
    subnetwork          = local.subnetwork
    pods_range_name     = local.pods_range_name
    services_range_name = local.services_range_name

    # Cluster settings
    auto_upgrade    = local.auto_upgrade
    release_channel = local.release_channel

    # Additional cluster details
    cluster_ipv4_cidr = google_container_cluster.primary.cluster_ipv4_cidr

    # Master auth (additional fields if needed)
    master_authorized_networks_config = local.whitelisted_cidrs

    # Workload identity
    workload_identity_config_workload_pool = "${local.project_id}.svc.id.goog"

    # Maintenance window
    maintenance_policy_enabled = local.auto_upgrade

    secrets = ["cluster_ca_certificate"]
  }

  output_interfaces = {
    kubernetes = {
      host                   = "https://${google_container_cluster.primary.endpoint}"
      cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
      kubernetes_provider_exec = {
        api_version = "client.authentication.k8s.io/v1"
        command     = "bash"
        args        = ["-c", local.exec_bash_command]
      }
      secrets = ["cluster_ca_certificate"]
    }
  }
}
