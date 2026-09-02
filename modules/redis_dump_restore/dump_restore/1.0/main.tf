locals {
  spec   = var.instance.spec
  source = local.spec.source
  target = local.spec.target

  namespace    = coalesce(try(local.spec.namespace, null), "default")
  runner_image = coalesce(try(local.spec.image, null), "redis:7.2-alpine")
  tolerations  = coalesce(try([for _, toleration in local.spec.tolerations : toleration], null), [])

  options                  = merge({}, try(local.spec.options, {}))
  allow_target_reset       = coalesce(try(local.options.allow_target_reset, null), false)
  require_empty_target     = coalesce(try(local.options.require_empty_target, null), true)
  restore_replace          = coalesce(try(local.options.restore_replace, null), false)
  copy_ttl                 = coalesce(try(local.options.copy_ttl, null), true)
  scan_count               = coalesce(try(local.options.scan_count, null), 1000)
  sample_limit             = coalesce(try(local.options.sample_limit, null), 25)
  command_timeout_seconds  = coalesce(try(local.options.command_timeout_seconds, null), 15)
  restore_engine           = coalesce(try(local.options.restore_engine, null), "shell")
  redis_shake_bin          = coalesce(try(local.options.redis_shake_bin, null), "redis-shake")
  redis_shake_download_url = try(local.options.redis_shake_download_url, null) != null ? local.options.redis_shake_download_url : ""
  redis_shake_pipeline     = coalesce(try(local.options.redis_shake_pipeline_count_limit, null), 1024)
  redis_shake_max_qps      = coalesce(try(local.options.redis_shake_target_max_qps, null), 100000)
  redis_shake_log_level    = coalesce(try(local.options.redis_shake_log_level, null), "info")
  redis_shake_ncpu         = coalesce(try(local.options.redis_shake_ncpu, null), 0)
  existing_service_account = try(local.options.existing_service_account_name, "")
  slack_channel_id         = try(local.spec.slack.channel_id, "")
  slack_token              = try(local.spec.slack.token_secret, "")

  safe_name_raw = lower(replace(var.instance_name, "_", "-"))
  safe_name     = length(local.safe_name_raw) <= 45 ? local.safe_name_raw : format("%s-%s", substr(local.safe_name_raw, 0, 36), substr(sha256(local.safe_name_raw), 0, 8))
  state_name    = "${local.safe_name}-state"
  scripts_name  = "${local.safe_name}-scripts"
  sa_name       = "${local.safe_name}-runner"
  runner_sa     = local.existing_service_account != "" ? local.existing_service_account : local.sa_name

  common_labels = {
    app                          = "redis-dump-restore"
    resourceType                 = "redis_dump_restore"
    resourceName                 = var.instance_name
    "app.kubernetes.io/name"     = "redis-dump-restore"
    "app.kubernetes.io/instance" = var.instance_name
  }

  dataset_config = coalesce(try([
    for name, dataset in local.spec.datasets : {
      name        = name
      source_db   = coalesce(try(dataset.source_db, null), 0)
      target_db   = coalesce(try(dataset.target_db, null), 0)
      key_pattern = coalesce(try(dataset.key_pattern, null), "*")
    }
  ], null), [])

  datasets_tsv = join("\n", [
    for dataset in local.dataset_config : join("\t", [
      dataset.name,
      tostring(dataset.source_db),
      tostring(dataset.target_db),
      dataset.key_pattern
    ])
  ])

  config_script = <<-EOT
    SOURCE_HOST=${local.source.host}
    SOURCE_PORT=${coalesce(try(local.source.port, null), 6379)}
    SOURCE_AUTH_TOKEN=${try(local.source.auth_token, "")}
    SOURCE_TLS=${coalesce(try(local.source.tls, null), false)}
    TARGET_HOST=${local.target.host}
    TARGET_PORT=${coalesce(try(local.target.port, null), 6379)}
    TARGET_AUTH_TOKEN=${try(local.target.auth_token, "")}
    TARGET_TLS=${coalesce(try(local.target.tls, null), false)}
    STATE_CONFIGMAP=${local.state_name}
    NAMESPACE=${local.namespace}
    ALLOW_TARGET_RESET=${local.allow_target_reset}
    REQUIRE_EMPTY_TARGET=${local.require_empty_target}
    RESTORE_REPLACE=${local.restore_replace}
    COPY_TTL=${local.copy_ttl}
    SCAN_COUNT=${local.scan_count}
    SAMPLE_LIMIT=${local.sample_limit}
    REDIS_COMMAND_TIMEOUT_SECONDS=${local.command_timeout_seconds}
    RESTORE_ENGINE=${local.restore_engine}
    REDIS_SHAKE_BIN=${local.redis_shake_bin}
    REDIS_SHAKE_DOWNLOAD_URL=${local.redis_shake_download_url}
    REDIS_SHAKE_PIPELINE_COUNT_LIMIT=${local.redis_shake_pipeline}
    REDIS_SHAKE_TARGET_MAX_QPS=${local.redis_shake_max_qps}
    REDIS_SHAKE_LOG_LEVEL=${local.redis_shake_log_level}
    REDIS_SHAKE_NCPU=${local.redis_shake_ncpu}
    SLACK_CHANNEL_ID=${local.slack_channel_id}
    DATASETS_TSV='${local.datasets_tsv}'
  EOT

  runner_env = local.slack_token != "" ? [{
    name  = "SLACK_TOKEN"
    value = local.slack_token
  }] : []

  volume_mounts = [{
    name      = "scripts"
    mountPath = "/scripts"
    readOnly  = true
  }]

  volumes = [{
    name = "scripts"
    configMap = {
      name        = local.scripts_name
      defaultMode = 493
    }
  }]

  cronjob_specs = {
    driver = {
      schedule = "0 0 31 2 *"
      suspend  = true
      args     = ["run"]
    }
    preflight = {
      schedule = "0 0 31 2 *"
      suspend  = true
      args     = ["preflight"]
    }
    verify = {
      schedule = "0 0 31 2 *"
      suspend  = true
      args     = ["verify"]
    }
    poller = {
      schedule = "0 0 31 2 *"
      suspend  = true
      args     = ["status"]
    }
  }

  cronjob_resources = {
    for key, job in local.cronjob_specs : "cronjob-${key}" => {
      apiVersion = "batch/v1"
      kind       = "CronJob"
      metadata = {
        name      = "${local.safe_name}-${key}"
        namespace = local.namespace
        labels    = local.common_labels
      }
      spec = {
        schedule                   = job.schedule
        suspend                    = job.suspend
        concurrencyPolicy          = "Forbid"
        successfulJobsHistoryLimit = 3
        failedJobsHistoryLimit     = 3
        jobTemplate = {
          spec = {
            backoffLimit = 0
            template = {
              metadata = {
                labels = local.common_labels
              }
              spec = {
                serviceAccountName = local.runner_sa
                restartPolicy      = "Never"
                tolerations        = local.tolerations
                containers = [{
                  name            = key
                  image           = local.runner_image
                  imagePullPolicy = "IfNotPresent"
                  command         = ["/bin/sh", "/scripts/dump_restore.sh"]
                  args            = job.args
                  env             = local.runner_env
                  volumeMounts    = local.volume_mounts
                }]
                volumes = local.volumes
              }
            }
          }
        }
      }
    }
  }

  rbac_resources_all = {
    serviceaccount = {
      apiVersion = "v1"
      kind       = "ServiceAccount"
      metadata = {
        name      = local.sa_name
        namespace = local.namespace
        labels    = local.common_labels
      }
    }
    role = {
      apiVersion = "rbac.authorization.k8s.io/v1"
      kind       = "Role"
      metadata = {
        name      = local.sa_name
        namespace = local.namespace
        labels    = local.common_labels
      }
      rules = [{
        apiGroups = [""]
        resources = ["configmaps"]
        verbs     = ["get", "create", "patch", "update"]
      }]
    }
    rolebinding = {
      apiVersion = "rbac.authorization.k8s.io/v1"
      kind       = "RoleBinding"
      metadata = {
        name      = local.sa_name
        namespace = local.namespace
        labels    = local.common_labels
      }
      subjects = [{
        kind      = "ServiceAccount"
        name      = local.sa_name
        namespace = local.namespace
      }]
      roleRef = {
        apiGroup = "rbac.authorization.k8s.io"
        kind     = "Role"
        name     = local.sa_name
      }
    }
  }
  rbac_resources = {
    for key, resource in local.rbac_resources_all : key => resource
    if local.existing_service_account == ""
  }

  script_resources = {
    scripts = {
      apiVersion = "v1"
      kind       = "ConfigMap"
      metadata = {
        name      = local.scripts_name
        namespace = local.namespace
        labels    = local.common_labels
      }
      data = {
        "config.sh"       = local.config_script
        "dump_restore.sh" = file("${path.module}/scripts/dump_restore.sh")
      }
    }
  }

  resources_data = merge(local.rbac_resources, local.script_resources, local.cronjob_resources)
}

module "name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 63
  resource_name   = var.instance_name
  resource_type   = "redis-dump-restore"
  is_k8s          = true
  globally_unique = false
}

module "redis-dump-restore-resources" {
  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resources"
  name            = local.safe_name
  release_name    = module.name.name
  namespace       = local.namespace
  resources_data  = local.resources_data
  advanced_config = lookup(lookup(var.instance, "advanced", {}), "redis_dump_restore", {})
}
