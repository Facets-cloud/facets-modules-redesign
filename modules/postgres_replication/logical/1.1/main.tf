locals {
  spec = var.instance.spec

  source = local.spec.source
  target = local.spec.target

  namespace_spec = coalesce(lookup(local.spec, "namespace", null), "")
  namespace      = local.namespace_spec != "" ? local.namespace_spec : "default"

  runner_image = coalesce(lookup(local.spec, "image", null), "postgres:17-alpine")
  tolerations  = coalesce(try([for _, toleration in local.spec.tolerations : toleration], null), [])

  allow_mutation                   = coalesce(try(local.spec.options.allow_mutation, null), true)
  defer_secondary_indexes          = coalesce(try(local.spec.options.defer_secondary_indexes, null), true)
  fail_on_missing_replica_identity = coalesce(try(local.spec.options.fail_on_missing_replica_identity, null), true)
  foreign_key_validation_mode      = coalesce(try(local.spec.options.foreign_key_validation_mode, null), "strict")
  load_ready_timeout_seconds       = coalesce(try(local.spec.options.load_ready_timeout_seconds, null), 7200)
  max_concurrent_databases         = coalesce(try(local.spec.options.max_concurrent_databases, null), 2)
  allow_schema_reset               = coalesce(try(local.spec.options.allow_schema_reset, null), false)
  require_target_login_roles       = coalesce(try(local.spec.options.require_target_login_roles, null), true)
  target_login_role_mode           = coalesce(try(local.spec.options.target_login_role_mode, null), "manage")
  target_disk_gb                   = coalesce(try(local.spec.options.target_disk_gb, null), 0)
  target_autoresize_limit_gb       = coalesce(try(local.spec.options.target_autoresize_limit_gb, null), 0)

  slack_channel_id_raw = try(local.spec.slack.channel_id, null)
  slack_token_raw      = try(local.spec.slack.token_secret, null)
  slack_channel_id     = local.slack_channel_id_raw != null ? local.slack_channel_id_raw : ""
  slack_token          = local.slack_token_raw != null ? local.slack_token_raw : ""

  safe_name_raw          = lower(replace(var.instance_name, "_", "-"))
  safe_name              = length(local.safe_name_raw) <= 45 ? local.safe_name_raw : format("%s-%s", substr(local.safe_name_raw, 0, 36), substr(sha256(local.safe_name_raw), 0, 8))
  state_name             = "${local.safe_name}-state"
  scripts_name           = "${local.safe_name}-scripts"
  sa_name                = "${local.safe_name}-runner"
  role_secret_name       = "${local.safe_name}-target-role-passwords"
  credential_secret_name = "${local.safe_name}-credentials"

  common_labels = {
    app                          = "postgres-replication"
    resourceType                 = "postgres_replication"
    resourceName                 = var.instance_name
    "app.kubernetes.io/name"     = "postgres-replication"
    "app.kubernetes.io/instance" = var.instance_name
  }

  database_config = coalesce(try([
    for name, db in local.spec.databases : {
      name                 = name
      source_db            = db.source_db
      target_db            = db.target_db
      publication          = db.publication
      subscription         = db.subscription
      exclude_schemas      = try(db.exclude_schemas, [])
      exclude_tables       = try(db.exclude_tables, [])
      exclude_extensions   = try(db.exclude_extensions, [])
      exclude_foreign_keys = try(db.exclude_foreign_keys, [])
    }
  ], null), [])

  target_login_roles = toset(coalesce(try(local.target.login_roles, null), []))

  config_script = <<-EOT
    SOURCE_HOST=${local.source.host}
    SOURCE_PORT=${coalesce(lookup(local.source, "port", null), 5432)}
    SOURCE_ADMIN_USER=${local.source.admin_user}
    SOURCE_REPL_USER=${local.source.repl_user}
    SOURCE_AUTH_DB=${try(local.source.auth_db, "")}
    TARGET_HOST=${local.target.host}
    TARGET_PORT=${coalesce(lookup(local.target, "port", null), 5432)}
    TARGET_ADMIN_USER=${local.target.admin_user}
    TARGET_REPL_USER=${local.target.repl_user}
    ALLOW_MUTATION=${local.allow_mutation}
    STATE_CONFIGMAP=${local.state_name}
    NAMESPACE=${local.namespace}
    SLACK_CHANNEL_ID=${local.slack_channel_id}
    DEFER_SECONDARY_INDEXES=${local.defer_secondary_indexes}
    FAIL_ON_MISSING_REPLICA_IDENTITY=${local.fail_on_missing_replica_identity}
    FOREIGN_KEY_VALIDATION_MODE=${local.foreign_key_validation_mode}
    LOAD_READY_TIMEOUT_SECONDS=${local.load_ready_timeout_seconds}
    MAX_CONCURRENT_DATABASES=${local.max_concurrent_databases}
    ALLOW_SCHEMA_RESET=${local.allow_schema_reset}
    REQUIRE_TARGET_LOGIN_ROLES=${local.require_target_login_roles}
    TARGET_LOGIN_ROLE_MODE=${local.target_login_role_mode}
    TARGET_DISK_GB=${local.target_disk_gb}
    TARGET_AUTORESIZE_LIMIT_GB=${local.target_autoresize_limit_gb}
    DATABASES_JSON='${jsonencode(local.database_config)}'
    TARGET_LOGIN_ROLES_JSON='${jsonencode(sort(tolist(local.target_login_roles)))}'
  EOT

  runner_env = concat([
    {
      name = "SOURCE_ADMIN_PASSWORD"
      valueFrom = {
        secretKeyRef = {
          name = kubernetes_secret_v1.runner_credentials.metadata[0].name
          key  = "source_admin_password"
        }
      }
    },
    {
      name = "SOURCE_REPL_PASSWORD"
      valueFrom = {
        secretKeyRef = {
          name = kubernetes_secret_v1.runner_credentials.metadata[0].name
          key  = "source_repl_password"
        }
      }
    },
    {
      name = "TARGET_ADMIN_PASSWORD"
      valueFrom = {
        secretKeyRef = {
          name = kubernetes_secret_v1.runner_credentials.metadata[0].name
          key  = "target_admin_password"
        }
      }
    },
    {
      name = "TARGET_REPL_PASSWORD"
      valueFrom = {
        secretKeyRef = {
          name = kubernetes_secret_v1.runner_credentials.metadata[0].name
          key  = "target_repl_password"
        }
      }
    },
    {
      name = "TARGET_LOGIN_ROLE_PASSWORDS_JSON"
      valueFrom = {
        secretKeyRef = {
          name = kubernetes_secret_v1.target_login_role_passwords.metadata[0].name
          key  = "roles_json"
        }
      }
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
      args     = ["driver"]
    }
    preflight = {
      schedule = "0 0 31 2 *"
      suspend  = true
      args     = ["preflight-only"]
    }
    verify-parity = {
      schedule = "0 0 31 2 *"
      suspend  = true
      args     = ["verify-parity"]
    }
    verify-lag = {
      schedule = "*/15 * * * *"
      suspend  = !local.allow_mutation
      args     = ["verify-lag"]
    }
    poller = {
      schedule = "*/5 * * * *"
      suspend  = !local.allow_mutation
      args     = ["poll"]
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
                serviceAccountName = local.sa_name
                restartPolicy      = "Never"
                tolerations        = local.tolerations
                containers = [{
                  name            = key
                  image           = local.runner_image
                  imagePullPolicy = "IfNotPresent"
                  command         = ["/bin/sh", "/scripts/replicate.sh"]
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

  base_resources = {
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
      rules = [
        {
          apiGroups = [""]
          resources = ["configmaps"]
          verbs     = ["get", "create", "patch", "update"]
        }
      ]
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
    scripts = {
      apiVersion = "v1"
      kind       = "ConfigMap"
      metadata = {
        name      = local.scripts_name
        namespace = local.namespace
        labels    = local.common_labels
      }
      data = {
        "config.sh"    = local.config_script
        "replicate.sh" = file("${path.module}/scripts/replicate.sh")
      }
    }
  }

  resources_data = merge(local.base_resources, local.cronjob_resources)
}

resource "random_password" "target_login_roles" {
  for_each = local.target_login_roles

  length  = 32
  special = false
}

resource "kubernetes_secret_v1" "runner_credentials" {
  metadata {
    name      = local.credential_secret_name
    namespace = local.namespace
    labels    = local.common_labels
  }

  data = {
    source_admin_password = local.source.admin_password
    source_repl_password  = local.source.repl_password
    target_admin_password = local.target.admin_password
    target_repl_password  = local.target.repl_password
  }
}

resource "kubernetes_secret_v1" "target_login_role_passwords" {
  metadata {
    name      = local.role_secret_name
    namespace = local.namespace
    labels    = local.common_labels
  }

  data = {
    roles_json = jsonencode({
      for role, password in random_password.target_login_roles :
      role => password.result
    })
  }
}

module "name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 63
  resource_name   = var.instance_name
  resource_type   = "postgres-replication"
  is_k8s          = true
  globally_unique = false
}

module "postgres-replication-resources" {
  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resources"
  name            = local.safe_name
  release_name    = module.name.name
  namespace       = local.namespace
  resources_data  = local.resources_data
  advanced_config = lookup(lookup(var.instance, "advanced", {}), "postgres_replication", {})
}
