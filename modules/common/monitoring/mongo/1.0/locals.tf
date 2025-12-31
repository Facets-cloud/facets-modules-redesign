# Locals for monitoring-mongo module
locals {
  name = var.instance_name

  # Job name for Prometheus metrics (matches ServiceMonitor job label)
  exporter_job_name = "${var.instance_name}-exporter-prometheus-mongodb-exporter"

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
    "app.kubernetes.io/name"       = "mongodb-monitoring"
    "app.kubernetes.io/instance"   = var.instance_name
    "app.kubernetes.io/managed-by" = "facets"
    "facets.cloud/environment"     = var.environment.name
  }

  # MongoDB connection details from input
  mongo_host     = var.inputs.mongo.interfaces.writer.host
  mongo_port     = var.inputs.mongo.interfaces.writer.port
  mongo_username = var.inputs.mongo.interfaces.writer.username
  mongo_password = var.inputs.mongo.interfaces.writer.password

  # Extract namespace from MongoDB host (format: service.namespace.svc.cluster.local)
  mongo_namespace = try(split(".", local.mongo_host)[1], var.environment.namespace)

  # NEW:
  # Extract MongoDB cluster name
  # mongo_cluster_name = var.inputs.mongo.interfaces.writer.name

  # Replica set name follows KubeBlocks convention: {cluster-name}-mongodb
  # mongo_replica_set = "${local.mongo_cluster_name}-mongodb"

  # MongoDB URI for exporter - using primary service to avoid DNS mismatch
  # The exporter can still collect replica set metrics when connected via the service
  mongodb_uri = "mongodb://${local.mongo_username}:${local.mongo_password}@${local.mongo_host}:${local.mongo_port}/admin"

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
    mongodb_down = {
      severity     = "critical"
      for_duration = "1m"
    }
    mongodb_high_connections = {
      severity     = "warning"
      threshold    = 80
      for_duration = "5m"
    }
    mongodb_high_memory = {
      severity     = "warning"
      threshold_gb = 3
      for_duration = "5m"
    }
    mongodb_replication_lag = {
      severity          = "warning"
      threshold_seconds = 10
      for_duration      = "2m"
    }
    mongodb_replica_unhealthy = {
      severity     = "critical"
      for_duration = "1m"
    }
    mongodb_high_queued_operations = {
      severity     = "warning"
      threshold    = 100
      for_duration = "5m"
    }
    mongodb_slow_queries = {
      severity     = "warning"
      threshold    = 10 # Alert if > 10 slow queries/sec detected
      for_duration = "5m"
    }
  }

  # Build alert rules dynamically
  alert_rules = [
    for rule_name, rule_config in local.alerts :
    {
      alert = replace(title(rule_name), "_", "")
      expr = (
        rule_name == "mongodb_down" ?
        "mongodb_up{facets_resource_type=\"mongo\",facets_resource_name=\"${var.instance_name}\"} == 0" :

        rule_name == "mongodb_high_connections" ?
        "(mongodb_ss_connections{facets_resource_type=\"mongo\",facets_resource_name=\"${var.instance_name}\",conn_type=\"current\"} / mongodb_ss_connections{facets_resource_type=\"mongo\",facets_resource_name=\"${var.instance_name}\",conn_type=\"available\"}) * 100 > ${lookup(rule_config, "threshold", 80)}" :

        rule_name == "mongodb_high_memory" ?
        "mongodb_ss_mem_resident{facets_resource_type=\"mongo\",facets_resource_name=\"${var.instance_name}\"} / 1024 / 1024 / 1024 > ${lookup(rule_config, "threshold_gb", 3)}" :

        rule_name == "mongodb_replication_lag" ?
        "(max(mongodb_members_optimeDate{facets_resource_type=\"mongo\",facets_resource_name=\"${var.instance_name}\",member_state=\"PRIMARY\"}) - on() group_right mongodb_members_optimeDate{facets_resource_type=\"mongo\",facets_resource_name=\"${var.instance_name}\",member_state=\"SECONDARY\"}) / 1000 > ${lookup(rule_config, "threshold_seconds", 10)}" :

        rule_name == "mongodb_replica_unhealthy" ?
        "mongodb_members_health{facets_resource_type=\"mongo\",facets_resource_name=\"${var.instance_name}\"} == 0" :

        rule_name == "mongodb_high_queued_operations" ?
        "(mongodb_ss_globalLock_currentQueue{facets_resource_type=\"mongo\",facets_resource_name=\"${var.instance_name}\",count_type=\"readers\"} + mongodb_ss_globalLock_currentQueue{facets_resource_type=\"mongo\",facets_resource_name=\"${var.instance_name}\",count_type=\"writers\"}) > ${lookup(rule_config, "threshold", 100)}" :

        rule_name == "mongodb_slow_queries" ?
        "rate(mongodb_profile_slow_query_count{facets_resource_type=\"mongo\",facets_resource_name=\"${var.instance_name}\"}[5m]) > ${lookup(rule_config, "threshold", 10)}" :

        "unknown_alert"
      )
      for = lookup(rule_config, "for_duration", "5m")
      labels = merge(
        local.common_labels,
        {
          severity   = lookup(rule_config, "severity", "warning")
          alert_type = rule_name
          namespace  = local.mongo_namespace
        }
      )
      annotations = {
        summary = (
          rule_name == "mongodb_down" ?
          "MongoDB {{ $labels.instance }} is down" :

          rule_name == "mongodb_high_connections" ?
          "MongoDB connection usage is {{ $value | humanizePercentage }}" :

          rule_name == "mongodb_high_memory" ?
          "MongoDB memory usage is {{ $value | humanize }}GB" :

          rule_name == "mongodb_replication_lag" ?
          "MongoDB replication lag is {{ $value }}s" :

          rule_name == "mongodb_replica_unhealthy" ?
          "MongoDB replica member is unhealthy" :

          rule_name == "mongodb_high_queued_operations" ?
          "MongoDB has {{ $value }} queued operations" :

          rule_name == "mongodb_slow_queries" ?
          "MongoDB has {{ $value }} slow queries/sec detected" :

          "Unknown alert"
        )
        description = (
          rule_name == "mongodb_down" ?
          "MongoDB instance has been down for more than ${lookup(rule_config, "for_duration", "1m")}. Immediate action required." :

          rule_name == "mongodb_high_connections" ?
          "MongoDB connection usage has exceeded ${lookup(rule_config, "threshold", 80)}% for more than ${lookup(rule_config, "for_duration", "5m")}. Consider scaling or optimizing connection pooling." :

          rule_name == "mongodb_high_memory" ?
          "MongoDB resident memory usage has exceeded ${lookup(rule_config, "threshold_gb", 3)}GB for more than ${lookup(rule_config, "for_duration", "5m")}. Consider increasing memory limits." :

          rule_name == "mongodb_replication_lag" ?
          "MongoDB replication lag has exceeded ${lookup(rule_config, "threshold_seconds", 10)}s for more than ${lookup(rule_config, "for_duration", "2m")}. Check network connectivity and replica set health." :

          rule_name == "mongodb_replica_unhealthy" ?
          "MongoDB replica set member has been unhealthy for more than ${lookup(rule_config, "for_duration", "1m")}. Check member status with rs.status()." :

          rule_name == "mongodb_high_queued_operations" ?
          "MongoDB has more than ${lookup(rule_config, "threshold", 100)} queued operations for ${lookup(rule_config, "for_duration", "5m")}. Database may be overloaded." :

          rule_name == "mongodb_slow_queries" ?
          "MongoDB has detected {{ $value }} slow queries/sec for ${lookup(rule_config, "for_duration", "5m")}. Slow queries exceed the configured slowms threshold. Review with db.system.profile or enable profiling with db.setProfilingLevel(1, {slowms: 100})." :

          "Unknown alert description"
        )
        runbook_url = "https://github.com/percona/mongodb_exporter"
      }
    }
  ]
}