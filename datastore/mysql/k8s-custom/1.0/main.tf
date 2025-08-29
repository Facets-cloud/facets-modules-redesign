# MySQL Kubernetes Deployment - Simplified to Avoid API Rate Limits
# This module deploys MySQL on Kubernetes with minimal API calls

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
  special = true
}

# Local values for simplified configuration
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
  }

  type = "Opaque"
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

# MySQL StatefulSet - Single API call with minimal complexity
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

          env {
            name = "MYSQL_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql_secret.metadata[0].name
                key  = "mysql-root-password"
              }
            }
          }

          env {
            name = "MYSQL_DATABASE"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql_secret.metadata[0].name
                key  = "mysql-database"
              }
            }
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

          # Simplified liveness probe to reduce API calls
          liveness_probe {
            exec {
              command = ["mysqladmin", "ping", "-h", "localhost"]
            }
            initial_delay_seconds = 30
            period_seconds        = 30
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          # Simplified readiness probe
          readiness_probe {
            exec {
              command = ["mysqladmin", "ping", "-h", "localhost"]
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
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
