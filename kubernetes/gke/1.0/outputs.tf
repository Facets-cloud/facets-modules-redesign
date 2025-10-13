locals {
  output_attributes = {
    # Cluster identification
    cluster_id       = google_container_cluster.primary.id
    cluster_name     = google_container_cluster.primary.name
    cluster_location = google_container_cluster.primary.location
    cluster_version  = google_container_cluster.primary.master_version

    # Authentication - standard names matching EKS/AKS
    cluster_endpoint       = "https://${google_container_cluster.primary.endpoint}"
    cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
    kubernetes_provider_exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "bash"
      args        = ["-c", "command -v gke-gcloud-auth-plugin >/dev/null 2>&1 || (gcloud components install gke-gcloud-auth-plugin --quiet 2>/dev/null || (curl -sLo /tmp/gke-gcloud-auth-plugin https://dl.google.com/dl/cloudsdk/channels/rapid/components/google-cloud-sdk-gke-gcloud-auth-plugin-linux-x86_64.tar.gz && tar -xzf /tmp/gke-gcloud-auth-plugin -C /tmp && chmod +x /tmp/google-cloud-sdk/bin/gke-gcloud-auth-plugin && mv /tmp/google-cloud-sdk/bin/gke-gcloud-auth-plugin /usr/local/bin/gke-gcloud-auth-plugin)); export GOOGLE_APPLICATION_CREDENTIALS='${var.inputs.cloud_account.attributes.credentials}'; gke-gcloud-auth-plugin --project=${local.project_id}"]
    }

    # Project and region details
    project_id = local.project_id
    region     = local.region

    # Network configuration
    network             = local.network
    subnetwork          = local.subnetwork
    pods_range_name     = local.pods_range_name
    services_range_name = local.services_range_name

    # Node pool details
    node_pool_machine_type        = local.machine_type
    node_pool_disk_size_gb        = local.disk_size_gb
    node_pool_disk_type           = local.disk_type
    node_pool_autoscaling_enabled = local.enable_autoscaling
    node_pool_min_nodes           = local.enable_autoscaling ? local.min_nodes : null
    node_pool_max_nodes           = local.enable_autoscaling ? local.max_nodes : null

    # Cluster settings
    auto_upgrade    = local.auto_upgrade
    release_channel = local.release_channel

    # Additional cluster details
    cluster_ipv4_cidr        = google_container_cluster.primary.cluster_ipv4_cidr
    services_ipv4_cidr_block = google_container_cluster.primary.services_ipv4_cidr_block

    # Master auth (additional fields if needed)
    master_authorized_networks_config = local.whitelisted_cidrs

    # Workload identity
    workload_identity_config_workload_pool = "${local.project_id}.svc.id.goog"

    # Maintenance window
    maintenance_policy_enabled = local.auto_upgrade

    secrets = "[\"cluster_ca_certificate\"]"
  }

  output_interfaces = {
    kubernetes = {
      host                   = "https://${google_container_cluster.primary.endpoint}"
      cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
      exec = {
        api_version = "client.authentication.k8s.io/v1beta1"
        command     = "bash"
        args        = ["-c", "command -v gke-gcloud-auth-plugin >/dev/null 2>&1 || (gcloud components install gke-gcloud-auth-plugin --quiet 2>/dev/null || (curl -sLo /tmp/gke-gcloud-auth-plugin https://dl.google.com/dl/cloudsdk/channels/rapid/components/google-cloud-sdk-gke-gcloud-auth-plugin-linux-x86_64.tar.gz && tar -xzf /tmp/gke-gcloud-auth-plugin -C /tmp && chmod +x /tmp/google-cloud-sdk/bin/gke-gcloud-auth-plugin && mv /tmp/google-cloud-sdk/bin/gke-gcloud-auth-plugin /usr/local/bin/gke-gcloud-auth-plugin)); export GOOGLE_APPLICATION_CREDENTIALS='${var.inputs.cloud_account.attributes.credentials}'; gke-gcloud-auth-plugin --project=${local.project_id}"]
      }
      secrets = "[\"cluster_ca_certificate\"]"
    }
  }
}
