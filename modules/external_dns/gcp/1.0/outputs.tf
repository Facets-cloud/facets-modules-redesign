locals {
  output_attributes = {
    # Secret information (created by this module)
    # Note: Secret is created in BOTH external-dns and cert-manager namespaces
    # Output points to cert-manager namespace since that's what cert-manager module expects
    secret_name              = kubernetes_secret.cert_manager_gcp_secret.metadata[0].name
    secret_namespace         = local.cert_manager_namespace
    gcp_credentials_json_key = "credentials.json"

    # Cloud provider identifier
    provider = "gcp"

    # GCP-specific configuration
    project_id = local.project_id
    region     = local.region
  }
  output_interfaces = {}
}
