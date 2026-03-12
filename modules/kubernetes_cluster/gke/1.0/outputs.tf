locals {
  # Pure bash one-liner: generates GCP access token from SA key using curl+openssl, outputs ExecCredential JSON
  exec_bash_command = "set -e; echo '${local.credentials}' > /tmp/gc-$$.json; SA=$(grep -o '\"client_email\" *: *\"[^\"]*\"' /tmp/gc-$$.json | head -1 | cut -d'\"' -f4); sed -n '/\"private_key\"/s/.*\"private_key\" *: *\"//p' /tmp/gc-$$.json | sed 's/\",*$//' | sed 's/\\\\n/\\n/g' > /tmp/pk-$$.pem; NOW=$(date +%s); EXP=$((NOW+3600)); H=$(printf '{\"alg\":\"RS256\",\"typ\":\"JWT\"}' | openssl base64 | tr -d '=\\n' | tr '/+' '_-'); C=$(printf '{\"iss\":\"%s\",\"scope\":\"https://www.googleapis.com/auth/cloud-platform\",\"aud\":\"https://oauth2.googleapis.com/token\",\"iat\":%d,\"exp\":%d}' \"$SA\" \"$NOW\" \"$EXP\" | openssl base64 | tr -d '=\\n' | tr '/+' '_-'); S=$(printf '%s.%s' \"$H\" \"$C\" | openssl dgst -sha256 -sign /tmp/pk-$$.pem -binary | openssl base64 | tr -d '=\\n' | tr '/+' '_-'); RESP=$(curl -sf -X POST https://oauth2.googleapis.com/token -d \"grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=$H.$C.$S\"); AT=$(echo \"$RESP\" | grep -o '\"access_token\" *: *\"[^\"]*\"' | head -1 | cut -d'\"' -f4); printf '{\"apiVersion\":\"client.authentication.k8s.io/v1\",\"kind\":\"ExecCredential\",\"status\":{\"token\":\"%s\"}}' \"$AT\"; rm -f /tmp/gc-$$.json /tmp/pk-$$.pem"

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

    secrets = "[\"cluster_ca_certificate\"]"
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
      secrets = "[\"cluster_ca_certificate\"]"
    }
  }
}
