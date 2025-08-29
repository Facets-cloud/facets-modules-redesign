# MySQL Kubernetes Deployment - Fixed Authentication Issues
# This module deploys MySQL on Kubernetes with proper password handling

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
resource "random_password" "mysql_root_password" {
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
  mysql_version = var.instance.spec.version_config.mysql_version
  database_name = var.instance.spec.version_config.database_name
  namespace     = var.instance.spec.version_config.namespace
  root_password = var.instance.spec.version_config.root_password != null ? var.instance.spec.version_config.root_password : random_password.mysql_root_password[0].result

  # Sizing configuration
  replica_count  = var.instance.spec.sizing.replica_count
  storage_size   = var.instance.spec.sizing.storage_size
  cpu_request    = var.instance.spec.sizing.cpu_request
  memory_request = var.instance.spec.sizing.memory_request
  cpu_limit      = var.instance.spec.sizing.cpu_limit
  memory_limit   = var.instance.spec.sizing.memory_limit

  # Resource names - simplified naming to reduce API calls
  release_name     = "${var.instance_name}-mysql"
  service_name     = local.release_name
  secret_name      = "${local.release_name}-secret"
  statefulset_name = local.release_name

  # MySQL connection details
  mysql_port       = 3306
  primary_endpoint = "${local.service_name}.${local.namespace}.svc.cluster.local"
  reader_endpoint  = local.primary_endpoint # Simplified - same as primary for single instance

  # Connection strings
  writer_connection_string = "mysql://root:${local.root_password}@${local.primary_endpoint}:${local.mysql_port}/${local.database_name}"
  reader_connection_string = local.writer_connection_string # Simplified

  # Environment tags
  common_labels = merge(var.environment.cloud_tags, {
    "app.kubernetes.io/name"     = "mysql"
    "app.kubernetes.io/instance" = local.release_name
  })

  # MySQL initialization script for proper setup
  mysql_init_sql = <<-EOT
-- Initialize MySQL database properly
CREATE DATABASE IF NOT EXISTS ${local.database_name} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
FLUSH PRIVILEGES;
EOT
}

# MySQL Secret - Single API call
resource "kubernetes_secret" "mysql_secret" {
  metadata {
    name      = local.secret_name
    namespace = local.namespace
    labels    = local.common_labels
  }

  data = {
    "mysql-root-password" = local.root_password
    "mysql-database"      = local.database_name
    "mysql-user"          = "root"
  }

  type = "Opaque"
}

# MySQL ConfigMap for initialization
resource "kubernetes_config_map" "mysql_init" {
  metadata {
    name      = "${local.release_name}-init"
    namespace = local.namespace
    labels    = local.common_labels
  }

  data = {
    "init.sql" = local.mysql_init_sql
  }
}

# MySQL Service - Single API call
resource "kubernetes_service" "mysql_service" {
  metadata {
    name      = local.service_name
    namespace = local.namespace
    labels    = local.common_labels
  }

  spec {
    selector = {
      "app.kubernetes.io/name"     = "mysql"
      "app.kubernetes.io/instance" = local.release_name
    }

    port {
      name        = "mysql"
      port        = local.mysql_port
      target_port = "mysql"
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

# MySQL StatefulSet - Fixed authentication configuration
resource "kubernetes_stateful_set" "mysql" {
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
        "app.kubernetes.io/name"     = "mysql"
        "app.kubernetes.io/instance" = local.release_name
      }
    }

    template {
      metadata {
        labels = merge(local.common_labels, {
          "app.kubernetes.io/name"     = "mysql"
          "app.kubernetes.io/instance" = local.release_name
        })
      }

      spec {
        container {
          name  = "mysql"
          image = "mysql:${local.mysql_version}"

          port {
            name           = "mysql"
            container_port = local.mysql_port
            protocol       = "TCP"
          }

          # FIXED: Proper MySQL environment variables for authentication
          env {
            name  = "MYSQL_ROOT_PASSWORD"
            value = local.root_password
          }

          env {
            name  = "MYSQL_DATABASE"
            value = local.database_name
          }

          env {
            name  = "MYSQL_ROOT_HOST"
            value = "%" # Allow root access from any host
          }

          # Additional MySQL configuration for better security
          env {
            name  = "MYSQL_CHARSET"
            value = "utf8mb4"
          }

          env {
            name  = "MYSQL_COLLATION"
            value = "utf8mb4_unicode_ci"
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
            name       = "mysql-data"
            mount_path = "/var/lib/mysql"
          }

          volume_mount {
            name       = "mysql-init-scripts"
            mount_path = "/docker-entrypoint-initdb.d"
          }

          # FIXED: Improved health checks with proper authentication
          liveness_probe {
            exec {
              command = [
                "sh", "-c",
                "mysqladmin ping -u root -p${local.root_password} --silent"
              ]
            }
            initial_delay_seconds = 60 # Give more time for MySQL to start
            period_seconds        = 30
            timeout_seconds       = 10
            failure_threshold     = 3
          }

          readiness_probe {
            exec {
              command = [
                "sh", "-c",
                "mysql -u root -p${local.root_password} -e 'SELECT 1' >/dev/null 2>&1"
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
          name = "mysql-init-scripts"
          config_map {
            name = kubernetes_config_map.mysql_init.metadata[0].name
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
        name   = "mysql-data"
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
