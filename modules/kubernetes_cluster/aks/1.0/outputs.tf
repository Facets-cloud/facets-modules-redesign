locals {
  output_attributes = {
    oidc_issuer_url           = module.k8scluster.oidc_issuer_url
    cluster_id                = module.k8scluster.aks_id
    cluster_name              = module.k8scluster.aks_name
    cluster_fqdn              = module.k8scluster.cluster_fqdn
    cluster_private_fqdn      = module.k8scluster.cluster_private_fqdn
    cluster_endpoint          = module.k8scluster.host
    cluster_location          = module.k8scluster.location
    node_resource_group       = module.k8scluster.node_resource_group
    resource_group_name       = var.inputs.network_details.attributes.resource_group_name
    network_details           = var.inputs.network_details.attributes
    cluster_ca_certificate    = base64decode(module.k8scluster.cluster_ca_certificate)
    client_certificate        = base64decode(module.k8scluster.client_certificate)
    client_key                = base64decode(module.k8scluster.client_key)
    automatic_channel_upgrade = var.instance.spec.auto_upgrade_settings.automatic_channel_upgrade
    cloud_provider            = "AZURE"
    secrets                   = "[\"client_key\", \"client_certificate\", \"cluster_ca_certificate\"]"
  }
  output_interfaces = {
    kubernetes = {
      host                   = module.k8scluster.host
      client_key             = base64decode(module.k8scluster.client_key)
      client_certificate     = base64decode(module.k8scluster.client_certificate)
      cluster_ca_certificate = base64decode(module.k8scluster.cluster_ca_certificate)
      secrets                = "[\"client_key\", \"client_certificate\", \"cluster_ca_certificate\"]"
    }
  }
}