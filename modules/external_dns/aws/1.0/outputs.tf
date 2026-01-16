locals {
  output_attributes = {
    # Secret information (created by this module)
    # Note: Secret is created in BOTH external-dns and cert-manager namespaces
    # Output points to cert-manager namespace since that's what cert-manager module expects
    secret_name      = kubernetes_secret.cert_manager_r53_secret.metadata[0].name
    secret_namespace = local.cert_manager_namespace

    # AWS credential keys (for cert-manager integration)
    aws_access_key_id_key     = "access-key-id"
    aws_secret_access_key_key = "secret-access-key"

    # Cloud provider identifier
    provider = "aws"

    # AWS-specific configuration
    hosted_zone_id = local.hosted_zone_id
    region         = local.aws_region
  }
  output_interfaces = {}
}
