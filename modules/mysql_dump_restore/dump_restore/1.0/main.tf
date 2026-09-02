locals {
  spec   = var.instance.spec
  source = local.spec.source
  target = local.spec.target

  namespace    = coalesce(try(local.spec.namespace, null), "default")
  runner_image = coalesce(try(local.spec.image, null), "mysql:8.4")
  tolerations  = coalesce(try([for _, toleration in local.spec.tolerations : toleration], null), [])

  options                      = coalesce(try(local.spec.options, null), {})
  allow_target_reset           = coalesce(try(local.options.allow_target_reset, null), false)
  require_empty_target         = coalesce(try(local.options.require_empty_target, null), true)
  force_utc                    = coalesce(try(local.options.force_utc, null), true)
  default_character_set        = coalesce(try(local.options.default_character_set, null), "utf8mb4")
  allow_charset_mismatch       = coalesce(try(local.options.allow_charset_mismatch, null), false)
  allow_collation_mismatch     = coalesce(try(local.options.allow_collation_mismatch, null), false)
  allow_non_innodb             = coalesce(try(local.options.allow_non_innodb, null), false)
  strip_definers               = coalesce(try(local.options.strip_definers, null), true)
  min_max_allowed_packet_bytes = coalesce(try(local.options.min_max_allowed_packet_bytes, null), 67108864)
  lock_timeout_seconds         = coalesce(try(local.options.lock_timeout_seconds, null), 60)
  existing_service_account     = try(local.options.existing_service_account_name, "")
  slack_channel_id             = try(local.spec.slack.channel_id, "")
  slack_token                  = try(local.spec.slack.token_secret, "")

  safe_name_raw = lower(replace(var.instance_name, "_", "-"))
  safe_name     = length(local.safe_name_raw) <= 45 ? local.safe_name_raw : format("%s-%s", substr(local.safe_name_raw, 0, 36), substr(sha256(local.safe_name_raw), 0, 8))
  state_name    = "${local.safe_name}-state"
  scripts_name  = "${local.safe_name}-scripts"
  sa_name       = "${local.safe_name}-runner"
  runner_sa     = local.existing_service_account != "" ? local.existing_service_account : local.sa_name

  common_labels = {
    app                          = "mysql-dump-restore"
    resourceType                 = "mysql_dump_restore"
    resourceName                 = var.instance_name
    "app.kubernetes.io/name"     = "mysql-dump-restore"
    "app.kubernetes.io/instance" = var.instance_name
  }

  database_config = coalesce(try([
    for name, db in local.spec.databases : {
      name             = name
      source_db        = db.source_db
      target_db        = db.target_db
      exclude_tables   = try(db.exclude_tables, [])
      include_routines = try(db.include_routines, true)
      include_triggers = try(db.include_triggers, true)
      include_events   = try(db.include_events, false)
    }
  ], null), [])

  database_tsv = join("\n", [
    for db in local.database_config : join("\t", [
      db.name,
      db.source_db,
      db.target_db,
      length(db.exclude_tables) > 0 ? join(",", db.exclude_tables) : "__none__",
      tostring(db.include_routines),
      tostring(db.include_triggers),
      tostring(db.include_events)
    ])
  ])

  config_script = <<-EOT
    SOURCE_HOST=${local.source.host}
    SOURCE_PORT=${coalesce(try(local.source.port, null), 3306)}
    SOURCE_ADMIN_USER=${local.source.admin_user}
    TARGET_HOST=${local.target.host}
    TARGET_PORT=${coalesce(try(local.target.port, null), 3306)}
    TARGET_ADMIN_USER=${local.target.admin_user}
    STATE_CONFIGMAP=${local.state_name}
    NAMESPACE=${local.namespace}
    ALLOW_TARGET_RESET=${local.allow_target_reset}
    REQUIRE_EMPTY_TARGET=${local.require_empty_target}
    FORCE_UTC=${local.force_utc}
    DEFAULT_CHARACTER_SET=${local.default_character_set}
    ALLOW_CHARSET_MISMATCH=${local.allow_charset_mismatch}
    ALLOW_COLLATION_MISMATCH=${local.allow_collation_mismatch}
    ALLOW_NON_INNODB=${local.allow_non_innodb}
    STRIP_DEFINERS=${local.strip_definers}
    MIN_MAX_ALLOWED_PACKET_BYTES=${local.min_max_allowed_packet_bytes}
    LOCK_TIMEOUT_SECONDS=${local.lock_timeout_seconds}
    SLACK_CHANNEL_ID=${local.slack_channel_id}
    DATABASES_TSV='${local.database_tsv}'
  EOT

  runner_env = concat([
    {
      name  = "SOURCE_ADMIN_PASSWORD"
      value = local.source.admin_password
    },
    {
      name  = "TARGET_ADMIN_PASSWORD"
      value = local.target.admin_password
    }
    ], local.slack_token != "" ? [{
      name  = "SLACK_TOKEN"
      value = local.slack_token
  }] : [])

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
                  command         = ["/bin/bash", "/scripts/dump_restore.sh"]
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
  resource_type   = "mysql-dump-restore"
  is_k8s          = true
  globally_unique = false
}

module "mysql-dump-restore-resources" {
  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resources"
  name            = local.safe_name
  release_name    = module.name.name
  namespace       = local.namespace
  resources_data  = local.resources_data
  advanced_config = lookup(lookup(var.instance, "advanced", {}), "mysql_dump_restore", {})
}
