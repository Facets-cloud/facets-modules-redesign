# Random password generation for Redis authentication
resource "random_password" "redis_auth" {
  length  = 32
  special = true
  upper   = true
  lower   = true
  numeric = true
}

# Kubernetes namespace for Redis deployment
resource "kubernetes_namespace" "redis" {
  metadata {
    name = local.namespace
    labels = merge(
      var.environment.cloud_tags,
      {
        "app.kubernetes.io/name"       = "redis"
        "app.kubernetes.io/instance"   = var.instance_name
        "app.kubernetes.io/component"  = "database"
        "app.kubernetes.io/part-of"    = "datastore"
        "app.kubernetes.io/managed-by" = "facets"
        "facets.io/environment"        = var.environment.name
      }
    )
  }

  # Allow namespace recreation for testing
  lifecycle {
    ignore_changes = [
      metadata[0].labels,
    ]
  }
}

# Kubernetes secret for Redis authentication
resource "kubernetes_secret" "redis_auth" {
  metadata {
    name      = local.secret_name
    namespace = kubernetes_namespace.redis.metadata[0].name
    labels = merge(
      var.environment.cloud_tags,
      {
        "app.kubernetes.io/name"       = "redis"
        "app.kubernetes.io/instance"   = var.instance_name
        "app.kubernetes.io/component"  = "secret"
        "app.kubernetes.io/managed-by" = "facets"
      }
    )
  }

  data = {
    "redis-password" = local.redis_password
  }

  type = "Opaque"

  lifecycle {
    prevent_destroy = true
  }
}

# Simplified Helm release for Redis deployment - optimized to avoid rate limiting
resource "helm_release" "redis" {
  name       = local.redis_name
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "redis"
  version    = "17.15.2" # Using older, more stable version to reduce complexity
  namespace  = kubernetes_namespace.redis.metadata[0].name

  # Minimal configuration to avoid API rate limiting
  wait              = false # Critical: Disable to reduce API calls
  wait_for_jobs     = false # Critical: Disable to reduce API calls
  timeout           = 300   # Short timeout since we're not waiting
  cleanup_on_fail   = false # Keep for debugging
  dependency_update = false # Disable to reduce initial API calls

  # Minimal settings to reduce API pressure
  max_history  = 1     # Minimum history
  atomic       = false # Already disabled
  reset_values = true  # Ensure clean state
  reuse_values = false

  # Use only values block - no dynamic set blocks to reduce API calls
  values = [
    yamlencode({
      # Minimal required configuration
      fullnameOverride = local.redis_name

      # Use simple architecture
      architecture = "standalone" # Force standalone to reduce complexity

      # Minimal authentication
      auth = {
        enabled                   = true
        existingSecret            = kubernetes_secret.redis_auth.metadata[0].name
        existingSecretPasswordKey = "redis-password"
      }

      # Minimal master configuration
      master = {
        resources = {
          requests = {
            memory = "64Mi"
            cpu    = "25m"
          }
          limits = {
            memory = local.memory_limit
            cpu    = local.cpu_limit
          }
        }

        persistence = {
          enabled = false # Disable persistence initially to reduce complexity
        }

        # Simplified probes
        livenessProbe = {
          enabled             = true
          initialDelaySeconds = 30
          periodSeconds       = 30
          failureThreshold    = 6
        }

        readinessProbe = {
          enabled             = true
          initialDelaySeconds = 5
          periodSeconds       = 10
          failureThreshold    = 6
        }
      }

      # Disable features that cause API overhead
      metrics = {
        enabled = false
      }

      sentinel = {
        enabled = false
      }

      replica = {
        enabled = false # Force disable replicas to reduce complexity
      }

      # Minimal security context
      securityContext = {
        enabled   = true
        runAsUser = 1001
        fsGroup   = 1001
      }

      # Disable network policies
      networkPolicy = {
        enabled = false
      }

      # Minimal service account
      serviceAccount = {
        create = false # Use default to reduce API calls
      }
    })
  ]

  # Remove all dynamic set blocks and additional set blocks
  # Use only the values block above to minimize API calls

  # Simplified lifecycle
  lifecycle {
    ignore_changes = [
      version,
      repository,
    ]
  }

  depends_on = [
    kubernetes_namespace.redis,
    kubernetes_secret.redis_auth
  ]
}