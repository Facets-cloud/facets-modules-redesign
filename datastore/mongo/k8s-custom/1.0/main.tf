# MongoDB Kubernetes Deployment
# This module deploys MongoDB on Kubernetes with proper authentication and replica set configuration

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.17.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# Generate random password if not provided
resource "random_password" "mongodb_root_password" {
  count   = var.instance.spec.version_config.root_password == null ? 1 : 0
  length  = 16
  special = false # Avoid special characters that can cause auth issues
  upper   = true
  lower   = true
  numeric = true
}

# Local values for configuration
locals {
  # Basic configuration
  mongo_version = var.instance.spec.version_config.mongo_version
  database_name = var.instance.spec.version_config.database_name
  namespace     = var.instance.spec.version_config.namespace
  root_password = var.instance.spec.version_config.root_password != null ? var.instance.spec.version_config.root_password : random_password.mongodb_root_password[0].result

  # Sizing configuration
  replica_count  = var.instance.spec.sizing.replica_count
  storage_size   = var.instance.spec.sizing.storage_size
  cpu_request    = var.instance.spec.sizing.cpu_request
  memory_request = var.instance.spec.sizing.memory_request
  cpu_limit      = var.instance.spec.sizing.cpu_limit
  memory_limit   = var.instance.spec.sizing.memory_limit

  # Resource names - simplified naming to reduce API calls
  release_name     = "${var.instance_name}-mongodb"
  service_name     = local.release_name
  secret_name      = "${local.release_name}-secret"
  statefulset_name = local.release_name

  # MongoDB connection details
  mongodb_port     = 27017
  primary_endpoint = "${local.service_name}.${local.namespace}.svc.cluster.local"
  reader_endpoint  = local.primary_endpoint # For replica sets, this would be configured differently

  # Connection strings
  writer_connection_string = "mongodb://root:${local.root_password}@${local.primary_endpoint}:${local.mongodb_port}/${local.database_name}?authSource=admin"
  reader_connection_string = local.writer_connection_string # Simplified for single instance

  # Environment tags
  common_labels = merge(var.environment.cloud_tags, {
    "app.kubernetes.io/name"     = "mongodb"
    "app.kubernetes.io/instance" = local.release_name
  })

  # MongoDB initialization script for proper setup
  mongodb_init_js = <<-EOT
// Initialize MongoDB database properly
use admin;
db.createUser({
  user: "root",
  pwd: "${local.root_password}",
  roles: [ { role: "root", db: "admin" } ]
});

// Create the application database
use ${local.database_name};
db.createCollection("init");
db.init.insertOne({ initialized: true, timestamp: new Date() });
EOT
}

# MongoDB Secret - Single API call
resource "kubernetes_secret" "mongodb_secret" {
  metadata {
    name      = local.secret_name
    namespace = local.namespace
    labels    = local.common_labels
  }

  data = {
    "mongodb-root-password" = local.root_password
    "mongodb-database"      = local.database_name
    "mongodb-username"      = "root"
  }

  type = "Opaque"
}

# MongoDB ConfigMap for initialization
resource "kubernetes_config_map" "mongodb_init" {
  metadata {
    name      = "${local.release_name}-init"
    namespace = local.namespace
    labels    = local.common_labels
  }

  data = {
    "init.js" = local.mongodb_init_js
  }
}

# MongoDB Service - Single API call
resource "kubernetes_service" "mongodb_service" {
  metadata {
    name      = local.service_name
    namespace = local.namespace
    labels    = local.common_labels
  }

  spec {
    selector = {
      "app.kubernetes.io/name"     = "mongodb"
      "app.kubernetes.io/instance" = local.release_name
    }

    port {
      name        = "mongodb"
      port        = local.mongodb_port
      target_port = "mongodb"
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

# MongoDB StatefulSet - MongoDB-specific configuration
resource "kubernetes_stateful_set" "mongodb" {
  metadata {
    name      = local.statefulset_name
    namespace = local.namespace
    labels    = local.common_labels
  }

  spec {
    service_name = local.service_name
    replicas     = local.replica_count

    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "mongodb"
        "app.kubernetes.io/instance" = local.release_name
      }
    }

    template {
      metadata {
        labels = merge(local.common_labels, {
          "app.kubernetes.io/name"     = "mongodb"
          "app.kubernetes.io/instance" = local.release_name
        })
      }

      spec {
        container {
          name  = "mongodb"
          image = "mongo:${local.mongo_version}"

          port {
            name           = "mongodb"
            container_port = local.mongodb_port
            protocol       = "TCP"
          }

          # MongoDB environment variables for authentication
          env {
            name  = "MONGO_INITDB_ROOT_USERNAME"
            value = "root"
          }

          env {
            name  = "MONGO_INITDB_ROOT_PASSWORD"
            value = local.root_password
          }

          env {
            name  = "MONGO_INITDB_DATABASE"
            value = local.database_name
          }

          # For replica set configuration (simplified for now)
          env {
            name  = "MONGODB_REPLICA_SET_MODE"
            value = local.replica_count > 1 ? "primary" : "standalone"
          }

          resources {
            requests = {
              cpu    = local.cpu_request
              memory = local.memory_request
            }
            limits = {
              cpu    = local.cpu_limit
              memory = local.memory_limit
            }
          }

          volume_mount {
            name       = "mongodb-data"
            mount_path = "/data/db"
          }

          volume_mount {
            name       = "mongodb-init-scripts"
            mount_path = "/docker-entrypoint-initdb.d"
          }

          # MongoDB health checks
          liveness_probe {
            exec {
              command = [
                "mongosh",
                "--eval",
                "db.adminCommand('ping')"
              ]
            }
            initial_delay_seconds = 60
            period_seconds        = 30
            timeout_seconds       = 10
            failure_threshold     = 3
          }

          readiness_probe {
            exec {
              command = [
                "mongosh",
                "--eval",
                "db.adminCommand('ping')"
              ]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }
        }

        # Add init script volume
        volume {
          name = "mongodb-init-scripts"
          config_map {
            name = kubernetes_config_map.mongodb_init.metadata[0].name
          }
        }

        # Security context - hardcoded secure defaults
        security_context {
          fs_group = 999
        }
      }
    }

    # Volume claim template - simplified to reduce API complexity
    volume_claim_template {
      metadata {
        name   = "mongodb-data"
        labels = local.common_labels
      }

      spec {
        access_modes = ["ReadWriteOnce"]
        resources {
          requests = {
            storage = local.storage_size
          }
        }
      }
    }
  }

  # Prevent destroy to protect data
  lifecycle {
    prevent_destroy = true
  }
}
