locals {
  spec              = var.instance.spec
  cluster_issuer    = var.inputs.kubernetes_details.oidc_issuer_url
  issuer_url        = local.spec.issuer_url != "" ? local.spec.issuer_url : local.cluster_issuer
  client_id_list    = local.spec.client_id_list
  thumbprint_list   = local.spec.thumbprint_list
  user_defined_tags = local.spec.tags
}

data "tls_certificate" "issuer" {
  url = local.issuer_url
}

resource "aws_iam_openid_connect_provider" "gke" {
  url = local.issuer_url

  client_id_list = local.client_id_list
  thumbprint_list = (
    length(local.thumbprint_list) > 0
    ? local.thumbprint_list
    : [data.tls_certificate.issuer.certificates[0].sha1_fingerprint]
  )

  tags = merge(local.user_defined_tags, var.environment.cloud_tags)
}
