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
            args        = ["-c", "command -v gke-gcloud-auth-plugin >/dev/null 2>&1 || (gcloud components install gke-gcloud-auth-plugin --quiet 2>/dev/null || (curl -sLo /tmp/gke-gcloud-auth-plugin https://dl.google.com/gke-gcloud-auth-plugin/v0.5.8/linux-amd64/gke-gcloud-auth-plugin && chmod +x /tmp/gke-gcloud-auth-plugin && mv /tmp/gke-gcloud-auth-plugin /usr/local/bin/gke-gcloud-auth-plugin)); export GOOGLE_APPLICATION_CREDENTIALS='${var.inputs.cloud_account.attributes.credentials}'; export CLOUDSDK_CORE_PROJECT='${local.project_id}'; export CLOUDSDK_COMPUTE_REGION='${local.region}'; export USE_GKE_GCLOUD_AUTH_PLUGIN=True; gke-gcloud-auth-plugin"]
          }
        }
        name       = google_container_cluster.primary.name
        id         = google_container_cluster.primary.id
        version    = google_container_cluster.primary.master_version
        location   = google_container_cluster.primary.location
        project_id = local.project_id
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
