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
resource "kubernetes_secret" "external_dns_azure_secret" {
  depends_on = [kubernetes_namespace.namespace]
  metadata {
    name      = local.secret_name
    namespace = local.namespace
  }
  data = {
    "credentials.json" = lookup(data.kubernetes_secret_v1.dns.data, "credentials.json", "")
  }
}
