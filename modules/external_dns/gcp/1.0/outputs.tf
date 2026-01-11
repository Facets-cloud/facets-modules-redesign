locals {
  output_attributes = {
    # Secret information (created by this module)
    secret_name              = kubernetes_secret.external_dns_gcp_secret.metadata[0].name
    secret_namespace         = local.namespace
    gcp_credentials_json_key = "credentials.json"

    # Cloud provider identifier
    provider = "gcp"

    # GCP-specific configuration
    project_id = local.project_id
    region     = local.region
  }
  output_interfaces = {}
}
