module "name" {
  for_each        = local.artifactories_ecr
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  is_k8s          = true
  globally_unique = false
  resource_type   = "artifactory"
  resource_name   = replace(lower("${local.name}-${each.key}"), "_", "-")
  environment     = var.environment
  limit           = 52
}

resource "kubernetes_secret_v1" "ecr-token-refresher-configs" {
  for_each = local.artifactories_ecr
  metadata {
    name      = "${module.name[each.key].name}-config"
    namespace = local.namespace
  }
  data = {
    aws_access_key_id     = each.value["awsKey"]
    aws_access_secret_key = each.value["awsSecret"]
    aws_account           = each.value["awsAccountId"]
    aws_region            = each.value["awsRegion"]
    registry_url          = each.value["uri"]
    registry_name         = each.key
    secret_name           = module.name[each.key].name
  }
}

resource "kubernetes_cron_job_v1" "ecr-token-refresher-cron" {
  for_each = local.artifactories_ecr
  metadata {
    name      = module.name[each.key].name
    namespace = local.namespace
  }

  lifecycle {
    precondition {
      condition     = length(module.name[each.key].name) <= 52
      error_message = "CronJob name exceeds 52 characters"
    }
  }
  spec {
    concurrency_policy            = "Allow"
    failed_jobs_history_limit     = 1
    schedule                      = "5 */3 * * *"
    starting_deadline_seconds     = 20
    successful_jobs_history_limit = 1
    suspend                       = false
    job_template {
      metadata {}
      spec {
        backoff_limit = 4
        template {
          metadata {}
          spec {
            priority_class_name = "system-node-critical"
            dynamic "toleration" {
              for_each = length(local.node_pool_tolerations) > 0 ? local.node_pool_tolerations : [{
                operator = "Exists"
              }]
              content {
                key      = lookup(toleration.value, "key", null)
                operator = toleration.value.operator
                value    = lookup(toleration.value, "value", null)
                effect   = lookup(toleration.value, "effect", null)
              }
            }
            service_account_name            = kubernetes_service_account.ecr-token-refresher-sa[each.key].metadata.0.name
            automount_service_account_token = true
            node_selector                   = local.node_selector
            container {
              name              = "kubectl"
              image             = "xynova/aws-kubectl"
              image_pull_policy = "Always"
              command           = ["/bin/sh", "-c", file("${path.module}/ecr-token-refresher-command")]
              env {
                name = "AWS_ACCOUNT"
                value_from {
                  secret_key_ref {
                    key  = "aws_account"
                    name = kubernetes_secret_v1.ecr-token-refresher-configs[each.key].metadata[0].name
                  }
                }
              }
              env {
                name = "AWS_ACCESS_KEY_ID"
                value_from {
                  secret_key_ref {
                    key  = "aws_access_key_id"
                    name = kubernetes_secret_v1.ecr-token-refresher-configs[each.key].metadata[0].name
                  }
                }
              }
              env {
                name = "AWS_SECRET_ACCESS_KEY"
                value_from {
                  secret_key_ref {
                    key  = "aws_access_secret_key"
                    name = kubernetes_secret_v1.ecr-token-refresher-configs[each.key].metadata[0].name
                  }
                }
              }
              env {
                name = "AWS_REGION"
                value_from {
                  secret_key_ref {
                    key  = "aws_region"
                    name = kubernetes_secret_v1.ecr-token-refresher-configs[each.key].metadata[0].name
                  }
                }
              }
              env {
                name = "KEY_NAME"
                value_from {
                  secret_key_ref {
                    key  = "secret_name"
                    name = kubernetes_secret_v1.ecr-token-refresher-configs[each.key].metadata[0].name
                  }
                }
              }
              env {
                name = "DOCKER_REGISTRY_SERVER"
                value_from {
                  secret_key_ref {
                    key  = "registry_url"
                    name = kubernetes_secret_v1.ecr-token-refresher-configs[each.key].metadata[0].name
                  }
                }
              }
              env {
                name  = "NAMESPACE"
                value = local.namespace
              }
              env {
                name  = "INSTANCE_LABELS"
                value = local.labels
              }
            }
            restart_policy = "Never"
          }
        }
      }
    }
  }
}

resource "kubernetes_role_v1" "ecr-token-refresher-role" {
  for_each = local.artifactories_ecr
  metadata {
    name      = module.name[each.key].name
    namespace = local.namespace
  }
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "create", "delete", "patch"]
  }
  rule {
    api_groups = [""]
    resources  = ["serviceaccounts"]
    verbs      = ["get", "patch", "list"]
  }
}

resource "kubernetes_service_account" "ecr-token-refresher-sa" {
  for_each = local.artifactories_ecr
  metadata {
    name      = module.name[each.key].name
    namespace = local.namespace
  }
}

resource "kubernetes_role_binding_v1" "ecr-token-refresher-crb" {
  for_each = local.artifactories_ecr
  metadata {
    name      = module.name[each.key].name
    namespace = local.namespace
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.ecr-token-refresher-role[each.key].metadata.0.name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.ecr-token-refresher-sa[each.key].metadata.0.name
    namespace = local.namespace
  }
}


resource "kubernetes_job_v1" "ecr-token-refresher-initial" {
  for_each = local.artifactories_ecr

  wait_for_completion = true

  timeouts {
    create = "3m"
    update = "3m"
  }

  metadata {
    name      = "${module.name[each.key].name}-initial"
    namespace = local.namespace
  }
  spec {
    backoff_limit = 4
    template {
      metadata {}
      spec {
        priority_class_name = "system-node-critical"
        dynamic "toleration" {
          for_each = length(local.node_pool_tolerations) > 0 ? local.node_pool_tolerations : [{
            operator = "Exists"
          }]
          content {
            key      = lookup(toleration.value, "key", null)
            operator = toleration.value.operator
            value    = lookup(toleration.value, "value", null)
            effect   = lookup(toleration.value, "effect", null)
          }
        }
        service_account_name            = kubernetes_service_account.ecr-token-refresher-sa[each.key].metadata.0.name
        automount_service_account_token = true
        node_selector                   = local.node_selector
        container {
          name              = "kubectl"
          image             = "xynova/aws-kubectl"
          image_pull_policy = "Always"
          command           = ["/bin/sh", "-c", file("${path.module}/ecr-token-refresher-command")]
          env {
            name = "AWS_ACCOUNT"
            value_from {
              secret_key_ref {
                key  = "aws_account"
                name = kubernetes_secret_v1.ecr-token-refresher-configs[each.key].metadata[0].name
              }
            }
          }
          env {
            name = "AWS_ACCESS_KEY_ID"
            value_from {
              secret_key_ref {
                key  = "aws_access_key_id"
                name = kubernetes_secret_v1.ecr-token-refresher-configs[each.key].metadata[0].name
              }
            }
          }
          env {
            name = "AWS_SECRET_ACCESS_KEY"
            value_from {
              secret_key_ref {
                key  = "aws_access_secret_key"
                name = kubernetes_secret_v1.ecr-token-refresher-configs[each.key].metadata[0].name
              }
            }
          }
          env {
            name = "AWS_REGION"
            value_from {
              secret_key_ref {
                key  = "aws_region"
                name = kubernetes_secret_v1.ecr-token-refresher-configs[each.key].metadata[0].name
              }
            }
          }
          env {
            name = "KEY_NAME"
            value_from {
              secret_key_ref {
                key  = "secret_name"
                name = kubernetes_secret_v1.ecr-token-refresher-configs[each.key].metadata[0].name
              }
            }
          }
          env {
            name = "DOCKER_REGISTRY_SERVER"
            value_from {
              secret_key_ref {
                key  = "registry_url"
                name = kubernetes_secret_v1.ecr-token-refresher-configs[each.key].metadata[0].name
              }
            }
          }
          env {
            name  = "NAMESPACE"
            value = local.namespace
          }
          env {
            name  = "INSTANCE_LABELS"
            value = local.labels
          }
        }
        restart_policy = "Never"
      }
    }
  }
  depends_on = [
    kubernetes_cron_job_v1.ecr-token-refresher-cron,
    kubernetes_secret_v1.ecr-token-refresher-configs
  ]
}