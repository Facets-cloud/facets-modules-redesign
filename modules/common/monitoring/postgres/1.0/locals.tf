# Locals for monitoring-postgres module
locals {
  name = var.instance_name

  # Job name for Prometheus metrics (matches ServiceMonitor job label)
  exporter_job_name = "${var.instance_name}-exporter-prometheus-postgres-exporter"

  # Get Prometheus namespace from input
  prometheus_namespace = var.inputs.prometheus.attributes.namespace

  # Get node pool details from input
  node_pool_input  = lookup(var.inputs, "node_pool", {})
  node_pool_attrs  = lookup(local.node_pool_input, "attributes", {})
  node_selector    = lookup(local.node_pool_attrs, "node_selector", {})
  node_pool_taints = lookup(local.node_pool_attrs, "taints", [])

  # Convert taints from {key, value, effect} to tolerations format
  tolerations = [
    for taint in local.node_pool_taints : {
      key      = taint.key
      operator = "Equal"
      value    = taint.value
      effect   = taint.effect
    }
  ]

  # Common labels for monitoring resources
  common_labels = {
    "app.kubernetes.io/name"       = "postgresql-monitoring"
    "app.kubernetes.io/instance"   = var.instance_name
    "app.kubernetes.io/managed-by" = "facets"
    "facets.cloud/environment"     = var.environment.name
  }

  # PostgreSQL connection details from input
  postgres_host     = var.inputs.postgres.interfaces.writer.host
  postgres_port     = var.inputs.postgres.interfaces.writer.port
  postgres_database = var.inputs.postgres.attributes.database
  postgres_username = var.inputs.postgres.interfaces.writer.username
  postgres_password = var.inputs.postgres.interfaces.writer.password

  # CloudSQL connection details (format: project:region:instance)
  cloudsql_instance_connection_name = var.inputs.postgres.attributes.connection_name
  gcp_project_id                    = var.inputs.gcp_provider.attributes.project

  # PostgreSQL namespace (for exporter deployment)
  postgres_namespace = var.environment.namespace

  # CloudSQL Proxy configuration
  cloudsql_proxy_config = merge(
    {
      image_tag = "2.8.0"
      resources = {
        requests = {
          cpu    = "50m"
          memory = "64Mi"
        }
        limits = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }
    },
    lookup(var.instance.spec, "cloudsql_proxy", {})
  )

  # PostgreSQL connection URL for exporter (via CloudSQL Proxy on localhost)
  # CloudSQL proxy will be accessible at localhost:5432
  postgres_data_source_uri = "postgresql://${local.postgres_username}:${local.postgres_password}@localhost:5432/${local.postgres_database}?sslmode=enabled"

  # Feature flags
  enable_metrics   = true
  enable_alerts    = true
  metrics_interval = "30s"

  # Resource configuration with defaults
  resources = merge(
    {
      requests = {
        cpu    = "100m"
        memory = "128Mi"
      }
      limits = {
        cpu    = "200m"
        memory = "256Mi"
      }
    },
    lookup(var.instance.spec, "resources", {})
  )

  # Alert configurations - all enabled by default
  alerts = {
    postgresql_down = {
      severity     = "critical"
      for_duration = "1m"
    }
    postgresql_high_connections = {
      severity     = "warning"
      threshold    = 80
      for_duration = "5m"
    }
    postgresql_low_cache_hit_ratio = {
      severity     = "warning"
      threshold    = 90
      for_duration = "5m"
    }
    postgresql_replication_lag = {
      severity          = "warning"
      threshold_seconds = 10
      for_duration      = "2m"
    }
    postgresql_too_many_locks = {
      severity     = "warning"
      threshold    = 100
      for_duration = "5m"
    }
    postgresql_long_running_transactions = {
      severity          = "warning"
      threshold_seconds = 300
      for_duration      = "5m"
    }
    postgresql_deadlocks = {
      severity     = "warning"
      threshold    = 1
      for_duration = "1m"
    }
    postgresql_slow_queries = {
      severity     = "warning"
      threshold    = 10
      for_duration = "5m"
    }
  }

  # Build alert rules dynamically
  alert_rules = [
    for rule_name, rule_config in local.alerts :
    {
      alert = replace(title(rule_name), "_", "")
      expr = (
        rule_name == "postgresql_down" ?
        "pg_up{facets_resource_type=\"postgres\",facets_resource_name=\"${var.instance_name}\"} == 0" :

        rule_name == "postgresql_high_connections" ?
        "(sum(pg_stat_database_numbackends{facets_resource_type=\"postgres\",facets_resource_name=\"${var.instance_name}\"}) / sum(pg_settings_max_connections{facets_resource_type=\"postgres\",facets_resource_name=\"${var.instance_name}\"})) * 100 > ${lookup(rule_config, "threshold", 80)}" :

        rule_name == "postgresql_low_cache_hit_ratio" ?
        "((sum(pg_stat_database_blks_hit{facets_resource_type=\"postgres\",facets_resource_name=\"${var.instance_name}\"}) / (sum(pg_stat_database_blks_hit{facets_resource_type=\"postgres\",facets_resource_name=\"${var.instance_name}\"}) + sum(pg_stat_database_blks_read{facets_resource_type=\"postgres\",facets_resource_name=\"${var.instance_name}\"}))) * 100) < ${lookup(rule_config, "threshold", 90)}" :

        rule_name == "postgresql_replication_lag" ?
        "pg_replication_lag{facets_resource_type=\"postgres\",facets_resource_name=\"${var.instance_name}\"} > ${lookup(rule_config, "threshold_seconds", 10)}" :

        rule_name == "postgresql_too_many_locks" ?
        "sum(pg_locks_count{facets_resource_type=\"postgres\",facets_resource_name=\"${var.instance_name}\"}) > ${lookup(rule_config, "threshold", 100)}" :

        rule_name == "postgresql_long_running_transactions" ?
        "max(pg_stat_activity_max_tx_duration{facets_resource_type=\"postgres\",facets_resource_name=\"${var.instance_name}\"}) > ${lookup(rule_config, "threshold_seconds", 300)}" :

        rule_name == "postgresql_deadlocks" ?
        "increase(pg_stat_database_deadlocks{facets_resource_type=\"postgres\",facets_resource_name=\"${var.instance_name}\"}[5m]) > ${lookup(rule_config, "threshold", 1)}" :

        rule_name == "postgresql_slow_queries" ?
        "rate(pg_stat_statements_mean_time_seconds{facets_resource_type=\"postgres\",facets_resource_name=\"${var.instance_name}\"}[5m]) > ${lookup(rule_config, "threshold", 10)}" :

        "unknown_alert"
      )
      for = lookup(rule_config, "for_duration", "5m")
      labels = merge(
        local.common_labels,
        {
          severity   = lookup(rule_config, "severity", "warning")
          alert_type = rule_name
          namespace  = local.postgres_namespace
        }
      )
      annotations = {
        summary = (
          rule_name == "postgresql_down" ?
          "PostgreSQL {{ $labels.instance }} is down" :

          rule_name == "postgresql_high_connections" ?
          "PostgreSQL connection usage is {{ $value | humanizePercentage }}" :

          rule_name == "postgresql_low_cache_hit_ratio" ?
          "PostgreSQL cache hit ratio is {{ $value | humanizePercentage }}" :

          rule_name == "postgresql_replication_lag" ?
          "PostgreSQL replication lag is {{ $value }}s" :

          rule_name == "postgresql_too_many_locks" ?
          "PostgreSQL has {{ $value }} active locks" :

          rule_name == "postgresql_long_running_transactions" ?
          "PostgreSQL has transactions running for {{ $value }}s" :

          rule_name == "postgresql_deadlocks" ?
          "PostgreSQL detected {{ $value }} deadlocks" :

          rule_name == "postgresql_slow_queries" ?
          "PostgreSQL has {{ $value }} slow queries/sec detected" :

          "Unknown alert"
        )
        description = (
          rule_name == "postgresql_down" ?
          "PostgreSQL instance has been down for more than ${lookup(rule_config, "for_duration", "1m")}. Immediate action required." :

          rule_name == "postgresql_high_connections" ?
          "PostgreSQL connection usage has exceeded ${lookup(rule_config, "threshold", 80)}% for more than ${lookup(rule_config, "for_duration", "5m")}. Consider scaling or optimizing connection pooling." :

          rule_name == "postgresql_low_cache_hit_ratio" ?
          "PostgreSQL cache hit ratio has been below ${lookup(rule_config, "threshold", 90)}% for more than ${lookup(rule_config, "for_duration", "5m")}. Consider increasing shared_buffers or investigating query patterns." :

          rule_name == "postgresql_replication_lag" ?
          "PostgreSQL replication lag has exceeded ${lookup(rule_config, "threshold_seconds", 10)}s for more than ${lookup(rule_config, "for_duration", "2m")}. Check network connectivity and replica health." :

          rule_name == "postgresql_too_many_locks" ?
          "PostgreSQL has more than ${lookup(rule_config, "threshold", 100)} active locks for ${lookup(rule_config, "for_duration", "5m")}. Database may have lock contention issues." :

          rule_name == "postgresql_long_running_transactions" ?
          "PostgreSQL has transactions running for more than ${lookup(rule_config, "threshold_seconds", 300)}s. Long-running transactions can cause bloat and block other queries." :

          rule_name == "postgresql_deadlocks" ?
          "PostgreSQL has detected ${lookup(rule_config, "threshold", 1)} or more deadlocks in the last 5 minutes. Review application transaction logic." :

          rule_name == "postgresql_slow_queries" ?
          "PostgreSQL has detected {{ $value }} slow queries/sec for ${lookup(rule_config, "for_duration", "5m")}. Review query performance with pg_stat_statements." :

          "Unknown alert description"
        )
        runbook_url = "https://github.com/prometheus-community/postgres_exporter"
      }
    }
  ]
}
