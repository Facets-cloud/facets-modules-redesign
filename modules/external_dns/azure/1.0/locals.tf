locals {
  namespace   = "external-dns"
  secret_name = "${lower(var.instance_name)}-dns-secret"
  region      = try(var.inputs.kubernetes_details.attributes.cluster_location, "eastus")
}

