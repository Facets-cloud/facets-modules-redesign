locals {
  spec           = lookup(var.instance, "spec", {})
  hosted_zone_id = lookup(local.spec, "hosted_zone_id", "*")
  cluster_name   = var.inputs.kubernetes_details.attributes.cluster_name
  namespace      = "external-dns"
  secret_name    = "${lower(var.instance_name)}-dns-secret"
  aws_region     = var.inputs.cloud_account.attributes.aws_region
}

