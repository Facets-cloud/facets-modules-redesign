locals {
  output_attributes = {
    cluster_id       = ovh_cloud_project_kube.cluster.id
    cluster_name     = ovh_cloud_project_kube.cluster.name
    cluster_endpoint = ovh_cloud_project_kube.cluster.kubeconfig_attributes[0].host
    # OVH returns base64 encoded certificates, decode them for provider use
    cluster_ca_certificate = base64decode(ovh_cloud_project_kube.cluster.kubeconfig_attributes[0].cluster_ca_certificate)
    client_certificate     = base64decode(ovh_cloud_project_kube.cluster.kubeconfig_attributes[0].client_certificate)
    client_key             = base64decode(ovh_cloud_project_kube.cluster.kubeconfig_attributes[0].client_key)
    kubeconfig             = ovh_cloud_project_kube.cluster.kubeconfig
    region                 = local.region
    version                = ovh_cloud_project_kube.cluster.version
    status                 = ovh_cloud_project_kube.cluster.status
    secrets                = ["cluster_ca_certificate", "client_certificate", "client_key", "kubeconfig"]
  }
  output_interfaces = {
    kubernetes = {
      host                   = ovh_cloud_project_kube.cluster.kubeconfig_attributes[0].host
      cluster_ca_certificate = base64decode(ovh_cloud_project_kube.cluster.kubeconfig_attributes[0].cluster_ca_certificate)
      client_certificate     = base64decode(ovh_cloud_project_kube.cluster.kubeconfig_attributes[0].client_certificate)
      client_key             = base64decode(ovh_cloud_project_kube.cluster.kubeconfig_attributes[0].client_key)
    }
  }
}
