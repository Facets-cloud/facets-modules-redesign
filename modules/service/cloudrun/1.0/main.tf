# =============================================================================
# LOCAL COMPUTATIONS
# =============================================================================

locals {
  resource_type = "service"
  resource_name = var.instance_name
  project_id = var.inputs.gcp_provider.attributes.project_id
  region     = var.inputs.gcp_provider.attributes.region
  job_name   = "${var.instance_name}-${var.environment.unique_name}"

  # Merge environment cloud tags with instance labels
  all_labels = merge(
    var.environment.cloud_tags,
    lookup(var.instance.spec, "labels", {})
  )

  # Container config
  container = lookup(var.instance.spec, "container", {})
  image     = lookup(local.container, "image", "")
  command   = lookup(local.container, "command", null)
  args      = lookup(local.container, "args", null)

  # Resources
  resources = lookup(var.instance.spec, "resources", {})
  cpu       = lookup(local.resources, "cpu", "2")
  memory    = lookup(local.resources, "memory", "4Gi")

  # Job config
  job_config   = lookup(var.instance.spec, "job", {})
  task_count   = lookup(local.job_config, "task_count", 1)
  parallelism  = lookup(local.job_config, "parallelism", 1)
  max_retries  = lookup(local.job_config, "max_retries", 3)
  task_timeout = lookup(local.job_config, "task_timeout", "3600s")

  # Environment variables
  env_vars = lookup(var.instance.spec, "env", {})

  # Secrets
  secrets = lookup(var.instance.spec, "secrets", {})

  # Service account
  service_account = lookup(var.instance.spec, "service_account", null)

  # VPC access
  vpc_access = lookup(var.instance.spec, "vpc_access", {})
  vpc_connector = (
    var.inputs.network != null &&
    lookup(local.vpc_access, "enabled", false)
  ) ? lookup(var.inputs.network.attributes, "vpc_connector_name", null) : null
}

# =============================================================================
# ENABLE REQUIRED APIS
# =============================================================================

resource "google_project_service" "run" {
  project            = local.project_id
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

# =============================================================================
# CLOUD RUN JOB
# =============================================================================

resource "google_cloud_run_v2_job" "this" {
  name     = local.job_name
  location = local.region
  project  = local.project_id

  labels = local.all_labels

  template {
    task_count  = local.task_count
    parallelism = local.parallelism

    template {
      max_retries = local.max_retries
      timeout     = local.task_timeout

      # Service account
      service_account = local.service_account

      # VPC access
      dynamic "vpc_access" {
        for_each = local.vpc_connector != null ? [1] : []
        content {
          connector = local.vpc_connector
          egress    = upper(replace(lookup(local.vpc_access, "egress", "private-ranges-only"), "-", "_"))
        }
      }

      containers {
        image   = local.image
        command = local.command
        args    = local.args

        # Resources
        resources {
          limits = {
            cpu    = local.cpu
            memory = local.memory
          }
        }

        # Environment variables
        dynamic "env" {
          for_each = local.env_vars
          content {
            name  = env.key
            value = env.value
          }
        }

        # Secrets from Secret Manager
        dynamic "env" {
          for_each = local.secrets
          content {
            name = env.key
            value_source {
              secret_key_ref {
                secret  = env.value.secret_name
                version = lookup(env.value, "version", "latest")
              }
            }
          }
        }
      }
    }
  }

  depends_on = [google_project_service.run]

  lifecycle {
    ignore_changes = [
      client,
      client_version,
    ]
  }
}
