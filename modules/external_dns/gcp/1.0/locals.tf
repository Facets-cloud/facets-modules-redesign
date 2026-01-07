locals {
  namespace   = "external-dns"
  secret_name = "${lower(var.instance_name)}-dns-secret"
  project_id  = var.inputs.cloud_account.attributes.project
  region      = try(var.inputs.cloud_account.attributes.region, "us-central1")
}

