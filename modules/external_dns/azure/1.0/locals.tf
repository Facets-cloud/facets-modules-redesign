locals {
  namespace   = "external-dns"
  secret_name = "${lower(var.instance_name)}-dns-secret"
}

