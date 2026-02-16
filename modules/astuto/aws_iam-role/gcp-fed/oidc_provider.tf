# Google OIDC Identity Provider in AWS
# Only ONE per AWS account — set create_oidc_provider=false for additional roles

# Look up existing Google OIDC provider (when create_oidc_provider=false)
data "aws_iam_openid_connect_provider" "google" {
  count = local.create_oidc_provider ? 0 : 1
  url   = "https://accounts.google.com"
}

# Create Google OIDC provider (when create_oidc_provider=true)
resource "aws_iam_openid_connect_provider" "google" {
  count = local.create_oidc_provider ? 1 : 0

  url = "https://accounts.google.com"

  # Audience = the auto-created GCP SA email
  client_id_list = [local.gcp_service_account_email]

  # Google's root CA thumbprint (stable, used by AWS to verify Google OIDC tokens)
  thumbprint_list = [
    "08745487e891c19e3078c1f2a07e452950ef36f6"
  ]

  tags = merge(var.environment.cloud_tags, {
    Name      = "${module.aws_iam_role_name.name}-google-oidc"
    ManagedBy = "facets"
  })
}
