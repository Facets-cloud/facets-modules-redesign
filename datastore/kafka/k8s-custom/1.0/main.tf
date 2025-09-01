# Local values for Kafka configuration
locals {
  # Basic configuration
  kafka_version      = var.instance.spec.version_config.version
  cluster_size       = var.instance.spec.version_config.cluster_size
  namespace          = "default" # Use default namespace
  storage_size       = var.instance.spec.sizing.storage_size
  memory_limit       = var.instance.spec.sizing.memory_limit
  cpu_limit          = var.instance.spec.sizing.cpu_limit
  enable_persistence = var.instance.spec.sizing.enable_persistence

  # Naming - Shortened to avoid 63 character limit
  # Take first 8 chars of instance_name and first 8 chars of unique_name
  short_instance_name = substr(var.instance_name, 0, 8)
  short_env_name      = substr(var.environment.unique_name, 0, 8)
  release_name        = "${local.short_instance_name}-${local.short_env_name}"
  service_name        = "${local.release_name}-kafka"

  # Authentication
  kafka_user     = "admin"
  kafka_password = random_password.kafka_password.result

  # Restore configuration
  restore_from_backup = try(var.instance.spec.restore_config.restore_from_backup, false)
  backup_source       = try(var.instance.spec.restore_config.backup_source, "")
}

# Generate secure password for Kafka authentication
resource "random_password" "kafka_password" {
  length  = 32
  special = true
}

# Create secret for Kafka authentication in default namespace
resource "kubernetes_secret" "kafka_auth" {
  metadata {
    name      = "${local.release_name}-auth"
    namespace = local.namespace
    labels = {
      "app.kubernetes.io/name"       = "kafka"
      "app.kubernetes.io/instance"   = local.release_name
      "app.kubernetes.io/component"  = "auth"
      "app.kubernetes.io/managed-by" = "facets"
    }
  }

  data = {
    "kafka-user"     = local.kafka_user
    "kafka-password" = local.kafka_password
  }

  type = "Opaque"
}

# Deploy Kafka using Helm in default namespace - Traditional Zookeeper mode
resource "helm_release" "kafka" {
  name       = local.release_name
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "kafka"
  version    = "26.8.5" # Chart version, not Kafka version
  namespace  = local.namespace

  # Reduced timeout for faster feedback - 5 minutes is sufficient for test environment
  timeout         = 300 # 5 minutes timeout - much faster feedback
  cleanup_on_fail = true
  wait            = true
  wait_for_jobs   = false # Don't wait for jobs to avoid timeout

  # Kafka configuration values - Optimized for resource-constrained test environment
  values = [
    yamlencode({
      image = {
        tag = local.kafka_version
      }

      # Use shorter names to avoid 63 character limit
      nameOverride     = local.release_name
      fullnameOverride = local.release_name

      # Explicitly disable KRaft mode
      kraft = {
        enabled = false
      }

      # Disable controller replicas for pure Zookeeper mode
      controller = {
        replicaCount = 0
      }

      # Configure broker replicas for Zookeeper mode - REDUCED RESOURCES
      broker = {
        replicaCount = 1 # Reduce to 1 broker for test environment
        persistence = {
          enabled      = local.enable_persistence
          size         = "10Gi" # Reduced size for testing
          storageClass = "gp2"
          accessModes  = ["ReadWriteOnce"]
        }
        resources = {
          limits = {
            memory = "512Mi" # Reduced from 2Gi
            cpu    = "500m"  # Reduced from 1000m
          }
          requests = {
            memory = "256Mi" # Conservative request
            cpu    = "250m"  # Conservative request
          }
        }
        # Add startup and liveness probes for better reliability
        livenessProbe = {
          enabled             = true
          initialDelaySeconds = 60
          periodSeconds       = 30
          timeoutSeconds      = 10
          failureThreshold    = 6
        }
        readinessProbe = {
          enabled             = true
          initialDelaySeconds = 30
          periodSeconds       = 10
          timeoutSeconds      = 5
          failureThreshold    = 6
        }
      }

      # Set main replicaCount to 0 when using broker.replicaCount
      replicaCount = 0

      auth = {
        clientProtocol = "sasl"
        sasl = {
          mechanisms = "PLAIN"
          users      = [local.kafka_user]
          passwords  = [local.kafka_password]
        }
      }

      listeners = {
        client = {
          containerPort = 9092
          protocol      = "SASL_PLAINTEXT"
          name          = "CLIENT"
        }
        interbroker = {
          containerPort = 9093
          protocol      = "SASL_PLAINTEXT"
          name          = "INTERNAL"
        }
        external = {
          containerPort = 9094
          protocol      = "SASL_PLAINTEXT"
          name          = "EXTERNAL"
        }
      }

      # DISABLE METRICS/EXPORTERS to avoid image pull issues
      metrics = {
        kafka = {
          enabled = false # Disable to avoid exporter image issues
        }
        jmx = {
          enabled = false # Disable to avoid additional complexity
        }
      }

      # Disable all exporters to avoid image pull failures
      exporter = {
        enabled = false
      }

      # Configure log retention (7 days default) and connection timeouts
      logRetentionHours = 168
      logSegmentBytes   = 1073741824

      # Improve Zookeeper connection reliability
      extraEnvVars = [
        {
          name  = "KAFKA_ZOOKEEPER_CONNECTION_TIMEOUT_MS"
          value = "60000" # 60 seconds instead of default 6 seconds
        },
        {
          name  = "KAFKA_ZOOKEEPER_SESSION_TIMEOUT_MS"
          value = "60000" # 60 seconds for session timeout
        }
      ]

      # Service configuration
      service = {
        type = "ClusterIP"
        ports = {
          client = 9092
        }
      }

      # Zookeeper configuration - REDUCED RESOURCES for test environment
      zookeeper = {
        enabled          = true
        replicaCount     = 1 # Reduce to 1 Zookeeper node for testing
        nameOverride     = "${local.release_name}-zk"
        fullnameOverride = "${local.release_name}-zk"
        persistence = {
          enabled      = local.enable_persistence
          size         = "5Gi" # Reduced size
          storageClass = "gp2"
          accessModes  = ["ReadWriteOnce"]
        }
        resources = {
          limits = {
            memory = "256Mi" # Reduced from 1Gi
            cpu    = "250m"  # Reduced from 500m
          }
          requests = {
            memory = "128Mi" # Conservative request
            cpu    = "100m"  # Conservative request
          }
        }
        auth = {
          enabled = false # Simplify for internal communication
        }
        metrics = {
          enabled = false
        }
        # Add startup probes for better reliability
        livenessProbe = {
          enabled             = true
          initialDelaySeconds = 60
          periodSeconds       = 30
          timeoutSeconds      = 10
          failureThreshold    = 6
        }
        readinessProbe = {
          enabled             = true
          initialDelaySeconds = 30
          periodSeconds       = 10
          timeoutSeconds      = 5
          failureThreshold    = 6
        }
        # Use security context instead of volume permissions
        securityContext = {
          enabled      = true
          fsGroup      = 1001
          runAsUser    = 1001
          runAsGroup   = 1001
          runAsNonRoot = true
        }
        # Disable volume permissions for Zookeeper too
        volumePermissions = {
          enabled = false
        }
      }

      # Explicitly disable external access 
      externalAccess = {
        enabled = false
      }

      # Disable provisioning that might interfere
      provisioning = {
        enabled = false
      }

      # Disable service monitor to avoid additional dependencies
      serviceMonitor = {
        enabled = false
      }

      # Disable pod monitor
      podMonitor = {
        enabled = false
      }

      # Disable volume permissions init container to avoid failures
      # Using fsGroup in securityContext instead for proper permissions
      volumePermissions = {
        enabled = false
      }

      # Use proper security context for volume permissions
      securityContext = {
        enabled      = true
        fsGroup      = 1001 # Kafka user group
        runAsUser    = 1001
        runAsGroup   = 1001
        runAsNonRoot = true
      }
    })
  ]

  depends_on = [
    kubernetes_secret.kafka_auth
  ]

  # REMOVED prevent_destroy for testing - allows updates/recreations
  # lifecycle {
  #   prevent_destroy = true
  # }
}

# Create service for external access in default namespace
resource "kubernetes_service" "kafka_external" {
  metadata {
    name      = "${local.release_name}-external"
    namespace = local.namespace
    labels = {
      "app.kubernetes.io/name"       = "kafka"
      "app.kubernetes.io/instance"   = local.release_name
      "app.kubernetes.io/component"  = "service"
      "app.kubernetes.io/managed-by" = "facets"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name"     = "kafka"
      "app.kubernetes.io/instance" = local.release_name
    }

    port {
      name        = "kafka"
      port        = 9092
      target_port = 9092
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }

  depends_on = [helm_release.kafka]
}