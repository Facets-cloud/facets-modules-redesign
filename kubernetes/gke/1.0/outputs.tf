locals {
  output_attributes = {
    # Cluster identification
    cluster_id   = google_container_cluster.primary.id
    cluster_name = google_container_cluster.primary.name

    # Endpoint and connection details
    endpoint       = "https://${google_container_cluster.primary.endpoint}"
    master_version = google_container_cluster.primary.master_version

    # Authentication details
    ca_certificate = google_container_cluster.primary.master_auth[0].cluster_ca_certificate

    # For Kubernetes provider authentication
    token = data.google_client_config.default.access_token

    # Location and project details
    location   = google_container_cluster.primary.location
    region     = local.region
    project_id = local.project_id

    # Network configuration
    network             = local.network
    subnetwork          = local.subnetwork
    pods_range_name     = local.pods_range_name
    services_range_name = local.services_range_name

    # Cluster configuration
    cluster_ipv4_cidr = google_container_cluster.primary.cluster_ipv4_cidr

    # Node pool details
    node_count   = local.initial_node_count
    machine_type = local.machine_type
    disk_size_gb = local.disk_size_gb
    disk_type    = local.disk_type

    # Autoscaling details
    autoscaling_enabled = local.enable_autoscaling
    min_nodes           = local.enable_autoscaling ? local.min_nodes : null
    max_nodes           = local.enable_autoscaling ? local.max_nodes : null

    # Security features
    workload_identity_enabled = true
    network_policy_enabled    = true
    binary_authorization      = true

    # Labels
    labels = local.cluster_labels
  }

  output_interfaces = {}
}