terraform {
  required_version = ">= 1.0"
}

# The user's password is generated here and published as a secret output. It is never
# accepted as spec input, so it cannot be committed to a blueprint. special = false
# keeps it clear of shell and SQL quoting hazards inside the provisioning job.
resource "random_password" "user" {
  length  = 32
  special = false
}

# Credentials reach the job only through this secret and only as environment
# variables, never as command arguments.
resource "kubernetes_secret_v1" "creds" {
  metadata {
    name      = local.secret_name
    namespace = local.namespace
    labels = {
      "facets.cloud/resource" = var.instance_name
    }
  }
  data = {
    admin_password = local.admin_password
    user_password  = random_password.user.result
  }
}

resource "kubernetes_job_v1" "provision" {
  metadata {
    name      = local.job_name
    namespace = local.namespace
    labels = {
      "facets.cloud/resource" = var.instance_name
    }
  }

  spec {
    backoff_limit = 2

    template {
      metadata {
        name = local.job_name
      }
      spec {
        restart_policy = "Never"

        container {
          name  = "mysql-provision"
          image = local.image

          command = ["bash", "-c", local.sql_script]

          env {
            name  = "DB_HOST"
            value = local.db_host
          }
          env {
            name  = "DB_PORT"
            value = tostring(local.db_port)
          }
          env {
            name  = "ADMIN_USER"
            value = local.admin_user
          }
          env {
            name  = "USERNAME"
            value = local.username
          }
          env {
            name  = "USER_HOST"
            value = local.user_host
          }
          # mysql(1) reads the password from MYSQL_PWD, which keeps it out of argv.
          env {
            name = "MYSQL_PWD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.creds.metadata[0].name
                key  = "admin_password"
              }
            }
          }
          env {
            name = "USER_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.creds.metadata[0].name
                key  = "user_password"
              }
            }
          }

          security_context {
            allow_privilege_escalation = false
            run_as_non_root            = true
            run_as_user                = 1000
            run_as_group               = 1000
            capabilities {
              drop = ["ALL"]
            }
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
          }
        }

        dynamic "toleration" {
          for_each = local.tolerations
          content {
            key      = lookup(toleration.value, "key", null)
            operator = lookup(toleration.value, "operator", "Equal")
            value    = lookup(toleration.value, "value", null)
            effect   = lookup(toleration.value, "effect", null)
          }
        }
      }
    }
  }

  # A silent failure here would hand the consuming service a user that does not
  # exist, so the apply must fail with the job rather than report success.
  wait_for_completion = true

  timeouts {
    create = "5m"
    update = "5m"
  }
}
