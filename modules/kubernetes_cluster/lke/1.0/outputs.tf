locals {
  output_attributes = {
    cluster_id       = tostring(linode_lke_cluster.cluster.id)
    cluster_name     = linode_lke_cluster.cluster.label
    cluster_endpoint = try(linode_lke_cluster.cluster.api_endpoints[0], "")
    cluster_location = local.region
    cloud_provider   = "LINODE"
    region           = local.region
    k8s_version      = linode_lke_cluster.cluster.k8s_version
    status           = linode_lke_cluster.cluster.status
    dashboard_url    = linode_lke_cluster.cluster.dashboard_url
    kubeconfig       = linode_lke_cluster.cluster.kubeconfig

    # Derived from the kubeconfig for the Kubernetes/Helm provider configuration.
    cluster_ca_certificate = local.cluster_ca_certificate
    token                  = local.cluster_token

    secrets = ["kubeconfig", "token", "cluster_ca_certificate"]
  }

  output_interfaces = {
    kubernetes = {
      host                   = try(linode_lke_cluster.cluster.api_endpoints[0], "")
      cluster_ca_certificate = local.cluster_ca_certificate
      token                  = local.cluster_token
    }
  }
}
