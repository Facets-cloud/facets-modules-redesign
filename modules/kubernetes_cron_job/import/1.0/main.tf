# CronJobs adopted from live (keyed by "<namespace>/<name>"). Container command/args are delivered
# base64-encoded to survive literal ${...} (shell vars) colliding with Facets interpolation.
resource "kubernetes_cron_job_v1" "main" {
  for_each = local.items

  metadata {
    name        = each.value.name
    namespace   = each.value.namespace
    labels      = lookup(each.value, "labels", null)
    annotations = lookup(each.value, "annotations", null)
  }

  spec {
    schedule                      = each.value.schedule
    concurrency_policy            = lookup(each.value, "concurrency_policy", null)
    failed_jobs_history_limit     = lookup(each.value, "failed_jobs_history_limit", null)
    successful_jobs_history_limit = lookup(each.value, "successful_jobs_history_limit", null)
    starting_deadline_seconds     = lookup(each.value, "starting_deadline_seconds", null)
    suspend                       = lookup(each.value, "suspend", null)

    job_template {
      metadata {}
      spec {
        backoff_limit = lookup(each.value, "backoff_limit", null)
        completions   = lookup(each.value, "completions", null)
        parallelism   = lookup(each.value, "parallelism", null)

        template {
          metadata {
            labels      = lookup(each.value.pod, "labels", null)
            annotations = lookup(each.value.pod, "annotations", null)
          }
          spec {
            restart_policy                   = lookup(each.value.pod, "restart_policy", null)
            service_account_name             = lookup(each.value.pod, "service_account_name", null)
            automount_service_account_token  = lookup(each.value.pod, "automount_service_account_token", null)
            dns_policy                       = lookup(each.value.pod, "dns_policy", null)
            enable_service_links             = lookup(each.value.pod, "enable_service_links", null)
            node_selector                    = lookup(each.value.pod, "node_selector", null)
            priority_class_name              = lookup(each.value.pod, "priority_class_name", null)
            termination_grace_period_seconds = lookup(each.value.pod, "termination_grace_period_seconds", null)

            dynamic "image_pull_secrets" {
              for_each = lookup(each.value.pod, "image_pull_secrets", [])
              content { name = image_pull_secrets.value.name }
            }
            dynamic "toleration" {
              for_each = lookup(each.value.pod, "tolerations", [])
              content {
                key                = lookup(toleration.value, "key", null) != "" ? lookup(toleration.value, "key", null) : null
                operator           = lookup(toleration.value, "operator", null)
                value              = lookup(toleration.value, "value", null) != "" ? lookup(toleration.value, "value", null) : null
                effect             = lookup(toleration.value, "effect", null) != "" ? lookup(toleration.value, "effect", null) : null
                toleration_seconds = lookup(toleration.value, "toleration_seconds", null) != "" ? lookup(toleration.value, "toleration_seconds", null) : null
              }
            }
            dynamic "container" {
              for_each = each.value.pod.containers
              content {
                name                       = container.value.name
                image                      = container.value.image
                image_pull_policy          = lookup(container.value, "image_pull_policy", null)
                command                    = lookup(container.value, "command_b64", null) != null ? [for s in container.value.command_b64 : base64decode(s)] : null
                args                       = lookup(container.value, "args_b64", null) != null ? [for s in container.value.args_b64 : base64decode(s)] : null
                termination_message_path   = lookup(container.value, "termination_message_path", null)
                termination_message_policy = lookup(container.value, "termination_message_policy", null)

                dynamic "env" {
                  for_each = lookup(container.value, "env", [])
                  content {
                    name  = env.value.name
                    value = lookup(env.value, "value", null) != "" ? lookup(env.value, "value", null) : null
                    dynamic "value_from" {
                      for_each = lookup(env.value, "secret_key_ref", null) != null ? [env.value.secret_key_ref] : []
                      content {
                        secret_key_ref {
                          name     = value_from.value.name
                          key      = value_from.value.key
                          optional = lookup(value_from.value, "optional", null)
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
