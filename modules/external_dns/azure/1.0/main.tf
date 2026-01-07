# Kubernetes namespace for external-dns
resource "kubernetes_namespace" "namespace" {
  metadata {
    name = local.namespace
  }
}

# Read existing DNS credentials secret (created by platform)
data "kubernetes_secret_v1" "dns" {
  metadata {
    name      = "facets-tenant-dns"
    namespace = "default"
  }
}

# Kubernetes secret with Azure DNS credentials
# cert-manager expects the client secret in a key named "client-secret"
resource "kubernetes_secret" "external_dns_azure_secret" {
  depends_on = [kubernetes_namespace.namespace]
  metadata {
    name      = local.secret_name
    namespace = local.namespace
  }
  data = {
    # cert-manager azureDNS solver expects the key to be "client-secret"
    # Handle null data gracefully - use try() to safely access nested data
    "client-secret" = try(
      lookup(try(data.kubernetes_secret_v1.dns.data, {}), "client-secret", null),
      try(
        lookup(try(data.kubernetes_secret_v1.dns.data, {}), "credentials.json", null),
        ""
      )
    )
  }
}
