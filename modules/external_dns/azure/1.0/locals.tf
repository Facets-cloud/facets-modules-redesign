locals {
  spec = lookup(var.instance, "spec", {})

  # Namespace and secret
  namespace   = "external-dns"
  secret_name = "${lower(var.instance_name)}-dns-secret"

  # Azure account details (from cloud_account module)
  subscription_id = var.inputs.cloud_account.attributes.subscription_id
  tenant_id       = var.inputs.cloud_account.attributes.tenant_id
  client_id       = var.inputs.cloud_account.attributes.client_id

  # Resource group comes from kubernetes_details (AKS → network module)
  resource_group_name = var.inputs.kubernetes_details.attributes.resource_group_name

  # Region comes from cluster_location (AKS region) or network_details
  region = try(
    var.inputs.kubernetes_details.attributes.cluster_location,
    var.inputs.kubernetes_details.attributes.network_details.region,
    ""
  )
}

