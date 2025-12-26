# Locals for monitoring-mongo module
locals {
  name = var.instance_name

  # Get Prometheus namespace from input
  prometheus_namespace = var.inputs.prometheus.attributes.namespace

  # Merge default labels with custom labels
  common_labels = merge(
    {
      "app.kubernetes.io/name"       = "mongodb-monitoring"
      "app.kubernetes.io/instance"   = var.instance_name
      "app.kubernetes.io/managed-by" = "facets"
      "facets.cloud/environment"     = var.environment.name
    },
    lookup(var.instance.spec, "labels", {})
  )

  # MongoDB connection details from input
  mongo_host     = var.inputs.mongo.interfaces.writer.host
  mongo_port     = var.inputs.mongo.interfaces.writer.port
  mongo_username = var.inputs.mongo.interfaces.writer.username
  mongo_password = var.inputs.mongo.interfaces.writer.password

  # Extract namespace from MongoDB host (format: service.namespace.svc.cluster.local)
  mongo_namespace = try(split(".", local.mongo_host)[1], var.environment.namespace)

  # MongoDB URI for exporter
  mongodb_uri = var.inputs.mongo.interfaces.writer.connection_string
  # Feature flags
  enable_metrics   = lookup(var.instance.spec, "enable_metrics", true)
  enable_alerts    = lookup(var.instance.spec, "enable_alerts", true)
  metrics_interval = lookup(var.instance.spec, "metrics_interval", "30s")

  # Alert configurations with defaults
  alerts = merge(
    {
      mongodb_down = {
        enabled      = true
        severity     = "critical"
        for_duration = "1m"
      }
      mongodb_high_connections = {
        enabled      = true
        severity     = "warning"
        threshold    = 80
        for_duration = "5m"
      }
      mongodb_high_memory = {
        enabled      = true
        severity     = "warning"
        threshold_gb = 3
        for_duration = "5m"
      }
      mongodb_replication_lag = {
        enabled           = true
        severity          = "warning"
        threshold_seconds = 10
        for_duration      = "2m"
      }
      mongodb_replica_unhealthy = {
        enabled      = true
        severity     = "critical"
        for_duration = "1m"
      }
      mongodb_high_queued_operations = {
        enabled      = true
        severity     = "warning"
        threshold    = 100
        for_duration = "5m"
      }
      mongodb_slow_queries = {
        enabled      = true
        severity     = "info"
        threshold_ms = 100
        for_duration = "5m"
      }
    },
    lookup(var.instance.spec, "alerts", {})
  )

  # Build alert rules dynamically
  alert_rules = [
    for rule_name, rule_config in local.alerts :
    {
      alert = replace(title(rule_name), "_", "")
      expr = (
        rule_name == "mongodb_down" ?
        "mongodb_up{job=\"${local.name}-exporter\"} == 0" :

        rule_name == "mongodb_high_connections" ?
        "(mongodb_ss_connections{job=\"${local.name}-exporter\",conn_type=\"current\"} / mongodb_ss_connections{job=\"${local.name}-exporter\",conn_type=\"available\"}) * 100 > ${lookup(rule_config, "threshold", 80)}" :

        rule_name == "mongodb_high_memory" ?
        "mongodb_ss_mem{job=\"${local.name}-exporter\",type=\"resident\"} / 1024 / 1024 / 1024 > ${lookup(rule_config, "threshold_gb", 3)}" :

        rule_name == "mongodb_replication_lag" ?
        "(max(mongodb_mongod_replset_optime_date{job=\"${local.name}-exporter\",state=\"PRIMARY\"}) - on() group_right mongodb_mongod_replset_optime_date{job=\"${local.name}-exporter\",state=\"SECONDARY\"}) > ${lookup(rule_config, "threshold_seconds", 10)}" :

        rule_name == "mongodb_replica_unhealthy" ?
        "mongodb_mongod_replset_member_health{job=\"${local.name}-exporter\"} == 0" :

        rule_name == "mongodb_high_queued_operations" ?
        "(mongodb_ss_globalLock_currentQueue{job=\"${local.name}-exporter\",type=\"reader\"} + mongodb_ss_globalLock_currentQueue{job=\"${local.name}-exporter\",type=\"writer\"}) > ${lookup(rule_config, "threshold", 100)}" :

        rule_name == "mongodb_slow_queries" ?
        "rate(mongodb_ss_opcounters{job=\"${local.name}-exporter\"}[5m]) > ${lookup(rule_config, "threshold_ms", 100)}" :

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
          "MongoDB has elevated operation rate: {{ $value }} ops/s" :

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
          "MongoDB operation rate is elevated at {{ $value }} ops/s for ${lookup(rule_config, "for_duration", "5m")}. Review query performance with db.currentOp()." :

          "Unknown alert description"
        )
        runbook_url = "https://github.com/percona/mongodb_exporter"
      }
    }
    if lookup(rule_config, "enabled", true)
  ]
}