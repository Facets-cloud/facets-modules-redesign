locals {
  # GKE token exec for the kubernetes/helm/kubectl providers. The runner image
  # may lack gke-auth-plugin, so the command self-installs it — but all
  # providers exec this script CONCURRENTLY at plan start, so the install must
  # be race-safe: flock serializes to a single download (double-checked inside
  # the lock), the download lands in a per-process mktemp file INSIDE
  # /usr/local/bin (same filesystem), and mv -f is then an atomic rename — a
  # concurrent exec sees either no binary or a complete one, never a partial
  # write (a shared /tmp path corrupted under concurrency: exit 126).
  kubernetes_provider_exec = {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "bash"
    args        = ["-c", "command -v gke-auth-plugin >/dev/null 2>&1 || flock /usr/local/bin/.gke-auth-plugin.lock bash -c 'command -v gke-auth-plugin >/dev/null 2>&1 && exit 0; t=$(mktemp /usr/local/bin/.gke-auth-plugin.XXXXXX) && curl -fsSLo $t.tar.gz https://github.com/traviswt/gke-auth-plugin/releases/download/0.3.0/gke-auth-plugin_Linux_x86_64.tar.gz && tar -xzf $t.tar.gz -C /tmp gke-auth-plugin && chmod +x /tmp/gke-auth-plugin && mv -f /tmp/gke-auth-plugin $t && rm -f $t.tar.gz && mv -f $t /usr/local/bin/gke-auth-plugin'; echo '${local.credentials}' > /tmp/gcp-creds-$$.json && GOOGLE_APPLICATION_CREDENTIALS=/tmp/gcp-creds-$$.json gke-auth-plugin; rm -f /tmp/gcp-creds-$$.json"]
  }
  # tflint-ignore: terraform_unused_declarations
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
    kubernetes_provider_exec = local.kubernetes_provider_exec

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

  # tflint-ignore: terraform_unused_declarations
  output_interfaces = {
    kubernetes = {
      host                     = "https://${google_container_cluster.primary.endpoint}"
      cluster_ca_certificate   = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
      kubernetes_provider_exec = local.kubernetes_provider_exec
      secrets                  = ["cluster_ca_certificate"]
    }
  }
}
