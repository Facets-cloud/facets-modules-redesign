locals {
  output_attributes = {
    cluster_id       = tostring(vultr_kubernetes.cluster.id)
    cluster_name     = vultr_kubernetes.cluster.label
    cluster_endpoint = local.cluster_endpoint
    cluster_location = local.region
    cloud_provider   = "VULTR"
    region           = local.region
    k8s_version      = vultr_kubernetes.cluster.version
    status           = vultr_kubernetes.cluster.status
    cluster_subnet   = vultr_kubernetes.cluster.cluster_subnet
    kubeconfig       = vultr_kubernetes.cluster.kube_config

    # Derived from the kubeconfig for the Kubernetes/Helm provider configuration.
    cluster_ca_certificate = local.cluster_ca_certificate
    client_certificate     = local.client_certificate
    client_key             = local.client_key

    secrets = ["kubeconfig", "client_certificate", "client_key", "cluster_ca_certificate"]
  }

  output_interfaces = {
    kubernetes = {
      host                   = local.cluster_endpoint
      cluster_ca_certificate = local.cluster_ca_certificate
      client_certificate     = local.client_certificate
      client_key             = local.client_key
    }
  }
}
