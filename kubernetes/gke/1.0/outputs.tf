locals {
  output_attributes = {
    k8s_details = {
      cluster = {
        auth = {
          host                   = "https://${google_container_cluster.primary.endpoint}"
          cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
          kubernetes_provider_exec = {
            api_version = "client.authentication.k8s.io/v1beta1"
            command     = "bash"
            args        = ["-c", "command -v gke-gcloud-auth-plugin >/dev/null 2>&1 || (gcloud components install gke-gcloud-auth-plugin --quiet 2>/dev/null || (curl -sLo /tmp/gke-gcloud-auth-plugin https://dl.google.com/dl/cloudsdk/channels/rapid/components/google-cloud-sdk-gke-gcloud-auth-plugin-linux-x86_64.tar.gz && tar -xzf /tmp/gke-gcloud-auth-plugin -C /tmp && chmod +x /tmp/google-cloud-sdk/bin/gke-gcloud-auth-plugin && mv /tmp/google-cloud-sdk/bin/gke-gcloud-auth-plugin /usr/local/bin/gke-gcloud-auth-plugin)); export GOOGLE_APPLICATION_CREDENTIALS='${var.inputs.cloud_account.attributes.credentials}'; gke-gcloud-auth-plugin --project=${local.project_id}"]
          }
        }
        name            = google_container_cluster.primary.name
        id              = google_container_cluster.primary.id
        version         = google_container_cluster.primary.master_version
        location        = google_container_cluster.primary.location
        project_id      = local.project_id
      }
      node_pool = {
        # Default node pool details
        machine_type        = local.machine_type
        disk_size_gb        = local.disk_size_gb
        disk_type           = local.disk_type
        autoscaling_enabled = local.enable_autoscaling
        min_nodes           = local.enable_autoscaling ? local.min_nodes : null
        max_nodes           = local.enable_autoscaling ? local.max_nodes : null
      }
    }
    secrets = ["k8s_details"]
  }

  output_interfaces = {}
}

output "legacy_outputs" {
  value = {
    registry_secret_objects         = []
    facets_dedicated_tolerations    = []
    facets_dedicated_node_selectors = {}
    k8s_details = {
      auth = {
        host                   = "https://${google_container_cluster.primary.endpoint}"
        cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
        token                  = data.google_client_config.default.access_token
      }
      cluster_name    = google_container_cluster.primary.name
      cluster_id      = google_container_cluster.primary.id
      cluster_version = google_container_cluster.primary.master_version
      location        = google_container_cluster.primary.location
      project_id      = local.project_id

      # Network details
      network             = local.network
      subnetwork          = local.subnetwork
      pods_range_name     = local.pods_range_name
      services_range_name = local.services_range_name

      # Security features
      workload_identity_enabled = true
      network_policy_enabled    = true
      binary_authorization      = true
    }
    gcp_cloud = {
      region     = local.region
      project_id = local.project_id
    }
  }
}