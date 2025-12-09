locals {
  output_interfaces = {}
  output_attributes = {
    "k8s_sa_name"                   = local.k8s_sa_name
    "k8s_sa_namespace"              = local.k8s_sa_namespace
    "managed_identity_id"           = local.managed_identity_id
    "managed_identity_client_id"    = local.managed_identity_client_id
    "managed_identity_principal_id" = local.managed_identity_principal_id
  }
}