locals {
  output_attributes = {
    provider_arn   = aws_iam_openid_connect_provider.gke.arn
    issuer_url     = aws_iam_openid_connect_provider.gke.url
    client_id_list = aws_iam_openid_connect_provider.gke.client_id_list
  }
  output_interfaces = {}
}
