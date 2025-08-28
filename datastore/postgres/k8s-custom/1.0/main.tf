# PostgreSQL on Kubernetes using Bitnami Helm Chart

# Random password generation (only used when not restoring from backup)
resource "random_password" "postgres_password" {
  length  = 16
  special = true
}

# Kubernetes namespace (if it doesn't exist)
resource "kubernetes_namespace" "postgres_namespace" {
  count = local.namespace != "default" ? 1 : 0

  metadata {
    name = local.namespace
    labels = {
      name                           = local.namespace
      "app.kubernetes.io/managed-by" = "facets"
    }
  }
}

# PostgreSQL Helm release using Bitnami chart
resource "helm_release" "postgresql" {
  name       = local.helm_release_name
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  version    = "13.2.24" # Bitnami PostgreSQL chart version
  namespace  = local.namespace

  # Wait for namespace to be created if needed
  depends_on = [kubernetes_namespace.postgres_namespace]

  # Core configuration values
  values = [
    yamlencode(local.postgres_values)
  ]

  # Additional Helm configuration
  timeout         = 600 # 10 minutes timeout
  cleanup_on_fail = true
  wait            = true
  wait_for_jobs   = true
}

# Kubernetes service for external access (if needed)
resource "kubernetes_service" "postgres_external" {
  count = var.instance.spec.sizing.architecture == "standalone" ? 1 : 0

  metadata {
    name      = "${local.helm_release_name}-external"
    namespace = local.namespace
    labels = {
      "app.kubernetes.io/name"       = "postgresql"
      "app.kubernetes.io/instance"   = local.helm_release_name
      "app.kubernetes.io/managed-by" = "facets"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name"      = "postgresql"
      "app.kubernetes.io/instance"  = local.helm_release_name
      "app.kubernetes.io/component" = "primary"
    }

    port {
      name        = "postgres"
      port        = local.postgres_port
      target_port = "postgres"
    }

    type = "ClusterIP"
  }

  depends_on = [helm_release.postgresql]
}