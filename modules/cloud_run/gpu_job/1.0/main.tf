# =============================================================================
# LOCAL COMPUTATIONS
# =============================================================================

locals {
  project_id = var.inputs.cloud_account.attributes.project_id
  region     = var.inputs.cloud_account.attributes.region
  job_name   = "${var.instance_name}-${var.environment.unique_name}"

  # Container config
  container = lookup(var.instance.spec, "container", {})
  image     = lookup(local.container, "image", "")
  command   = lookup(local.container, "command", null)
  args      = lookup(local.container, "args", null)

  # GPU config
  gpu_config  = lookup(var.instance.spec, "gpu", {})
  gpu_enabled = lookup(local.gpu_config, "enabled", true)
  gpu_type    = lookup(local.gpu_config, "type", "nvidia-rtx-pro-6000")

  # Resources (RTX PRO 6000 requires min 20 CPU, 80GiB memory)
  resources = lookup(var.instance.spec, "resources", {})
  cpu       = lookup(local.resources, "cpu", "20")
  memory    = lookup(local.resources, "memory", "80Gi")

  # Job config
  job_config   = lookup(var.instance.spec, "job", {})
  task_count   = lookup(local.job_config, "task_count", 1)
  parallelism  = lookup(local.job_config, "parallelism", 1)
  max_retries  = lookup(local.job_config, "max_retries", 3)
  task_timeout = lookup(local.job_config, "task_timeout", "3600s")

  # Environment variables
  env_vars = lookup(var.instance.spec, "env", {})

  # Secrets
  secrets = lookup(var.instance.spec, "secrets", [])

  # Service account
  service_account = lookup(var.instance.spec, "service_account", null)

  # VPC access
  vpc_access      = lookup(var.instance.spec, "vpc_access", null)
  network_details = lookup(var.inputs, "network_details", null)
  vpc_connector   = local.network_details != null ? lookup(local.network_details.attributes, "vpc_connector_name", null) : null
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

  deletion_protection = false

  template {
    task_count  = local.task_count
    parallelism = local.parallelism

    template {
      max_retries = local.max_retries
      timeout     = local.task_timeout

      # Disable GPU zonal redundancy (required for Cloud Run Jobs with GPU)
      gpu_zonal_redundancy_disabled = true

      # GPU node selector - specifies which GPU type to use
      dynamic "node_selector" {
        for_each = local.gpu_enabled ? [1] : []
        content {
          accelerator = local.gpu_type
        }
      }

      # Service account
      service_account = local.service_account

      # VPC access
      dynamic "vpc_access" {
        for_each = local.vpc_connector != null ? [1] : []
        content {
          connector = local.vpc_connector
          egress    = local.vpc_access != null ? lookup(local.vpc_access, "egress", "PRIVATE_RANGES_ONLY") : "PRIVATE_RANGES_ONLY"
        }
      }

      containers {
        image   = local.image
        command = local.command
        args    = local.args

        # Resources
        resources {
          limits = {
            cpu              = local.cpu
            memory           = local.memory
            "nvidia.com/gpu" = local.gpu_enabled ? "1" : "0"
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
            name = env.value.env_var
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

  # GPU jobs require ALPHA launch stage
  launch_stage = "ALPHA"

  # Labels
  labels = {
    "managed-by"  = "facets"
    "instance"    = var.instance_name
    "environment" = var.environment.unique_name
  }

  depends_on = [google_project_service.run]

  lifecycle {
    ignore_changes = [
      launch_stage,
    ]
  }
}
