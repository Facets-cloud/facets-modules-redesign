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

# Kubernetes secret with GCP DNS credentials
resource "kubernetes_secret" "external_dns_gcp_secret" {
  depends_on = [kubernetes_namespace.namespace]
  metadata {
    name      = local.secret_name
    namespace = local.namespace
  }
  data = {
    # Handle null data gracefully - use try() to safely access nested data
    "credentials.json" = try(
      lookup(try(data.kubernetes_secret_v1.dns.data, {}), "credentials.json", null),
      ""
    )
  }
}
