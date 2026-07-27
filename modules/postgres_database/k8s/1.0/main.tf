# PostgreSQL Database Module for Kubernetes
# Creates databases on an existing Aurora/RDS Postgres cluster using a Kubernetes Job
# This module allows creating databases on a cluster without modifying the cluster's own blueprint.

locals {
  # Get the writer connection details from the postgres_cluster input
  writer_interface = var.inputs.postgres_cluster.interfaces.writer

  # Generate a unique job name to avoid conflicts
  job_name = "${var.instance_name}-${var.environment.unique_name}"

  # PostgreSQL connection parameters
  pg_host     = local.writer_interface.host
  pg_port     = local.writer_interface.port
  pg_user     = local.writer_interface.username
  pg_password = local.writer_interface.password
  pg_database = "postgres" # Connect to default database to create new ones

  # Job configuration
  job_namespace = "default"
  job_timeout   = 3600 # 1 hour timeout for large database creation
  job_backoff   = 3    # 3 retries for transient failures

  # Container image for PostgreSQL client
  pg_client_image = "postgres:16-alpine"

  # Generate idempotent CREATE DATABASE commands for each database
  # Each database gets its own CREATE DATABASE IF NOT EXISTS block
  # This ensures the job is idempotent - running it multiple times won't fail if databases already exist
  create_database_commands = [
    for db in var.instance.spec.databases : join(" ", [
      "if ! psql -tAc \"SELECT 1 FROM pg_database WHERE datname='${db.name}'\" | grep -q 1; then",
      "psql -v ON_ERROR_STOP=1 -c \"CREATE DATABASE \\\"${db.name}\\\" OWNER \\\"${db.owner_role}\\\";\" &&",
      "psql -v ON_ERROR_STOP=1 -c \"GRANT ALL PRIVILEGES ON DATABASE \\\"${db.name}\\\" TO \\\"${db.owner_role}\\\";\" &&",
      "echo \"Database ${db.name} created\";",
      "else echo \"Database ${db.name} already exists, skipping\"; fi"
    ])
  ]

  # Join all commands with newlines for execution
  all_database_commands = join("\n", local.create_database_commands)
}

# Create databases on the existing cluster using a Kubernetes Job
resource "kubernetes_job_v1" "postgres_databases" {
  metadata {
    name      = local.job_name
    namespace = local.job_namespace

    annotations = {
      "facets.cloud/instance-name" = var.instance_name
      "facets.cloud/environment"   = var.environment.name
    }
  }

  spec {
    backoff_limit = local.job_backoff

    template {
      metadata {
        annotations = {
          "facets.cloud/instance-name" = var.instance_name
          "facets.cloud/environment"   = var.environment.name
        }
      }

      spec {
        container {
          name    = "create-databases"
          image   = local.pg_client_image
          command = ["/bin/sh", "-c"]

          # Create all databases and grant privileges to the existing owner role
          # Each database gets its own CREATE DATABASE IF NOT EXISTS block
          # This ensures the job is idempotent - running it multiple times won't fail if databases already exist
          args = [join("\n", [
            "set -e",
            "echo 'Creating databases on cluster...'",
            local.all_database_commands,
            "echo 'All databases created successfully!'"
          ])]

          env {
            name  = "PGHOST"
            value = local.pg_host
          }

          env {
            name  = "PGPORT"
            value = local.pg_port
          }

          env {
            name  = "PGUSER"
            value = local.pg_user
          }

          env {
            name  = "PGPASSWORD"
            value = local.pg_password
          }

          env {
            name  = "PGDATABASE"
            value = local.pg_database
          }

          env {
            name  = "PGSSLMODE"
            value = "require"
          }

          resources {
            requests = {
              cpu    = "200m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }

        restart_policy = "OnFailure"
      }
    }
  }

  timeouts {
    create = "${local.job_timeout}s"
    delete = "${local.job_timeout}s"
  }
}
