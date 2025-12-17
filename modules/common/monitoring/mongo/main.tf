# MongoDB Monitoring Module - KubeBlocks Alert Rules
# Creates PrometheusRule resources based on KubeBlocks MongoDB exporter metrics
# Reference: https://github.com/apecloud/kubeblocks-addons/blob/main/examples/mongodb/alert-rules.yaml

locals {
  name = "${var.instance_name}-${var.environment.unique_name}"

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

  # MongoDB service details from input
  mongo_service = var.inputs.mongo.attributes.service_name
  mongo_port    = var.inputs.mongo.attributes.port
  mongo_host    = var.inputs.mongo.interfaces.primary.host

  # Extract namespace and app labels for KubeBlocks metrics
  # KubeBlocks uses these labels: app_kubernetes_io_instance, namespace
  namespace_label = try(split(".", local.mongo_host)[1], var.environment.namespace)
  app_label       = var.instance_name

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

  # Build alert rules dynamically based on KubeBlocks MongoDB exporter metrics
  alert_rules = [
    for rule_name, rule_config in local.alerts :
    {
      alert = replace(title(rule_name), "_", "")
      expr = (
        rule_name == "mongodb_down" ?
        # Check if MongoDB is up using the 'up' metric from Prometheus
        "up{job=\"${local.mongo_service}\"} == 0" :

        rule_name == "mongodb_high_connections" ?
        # KubeBlocks metric: mongodb_ss_connections with conn_type label
        "(mongodb_ss_connections{conn_type=\"current\",app_kubernetes_io_instance=\"${local.app_label}\"} / mongodb_ss_connections{conn_type=\"available\",app_kubernetes_io_instance=\"${local.app_label}\"}) * 100 > ${lookup(rule_config, "threshold", 80)}" :

        rule_name == "mongodb_high_memory" ?
        # KubeBlocks metric: mongodb_ss_mem with type="resident"
        "mongodb_ss_mem{app_kubernetes_io_instance=\"${local.app_label}\",type=\"resident\"} / 1024 / 1024 / 1024 > ${lookup(rule_config, "threshold_gb", 3)}" :

        rule_name == "mongodb_replication_lag" ?
        # KubeBlocks metric: mongodb_rs_members_optimeDate - calculates lag between PRIMARY and SECONDARY
        "(max(mongodb_rs_members_optimeDate{app_kubernetes_io_instance=\"${local.app_label}\",member_state=\"PRIMARY\"}) - on() group_right mongodb_rs_members_optimeDate{app_kubernetes_io_instance=\"${local.app_label}\",member_state=\"SECONDARY\"}) > ${lookup(rule_config, "threshold_seconds", 10)}" :

        rule_name == "mongodb_replica_unhealthy" ?
        # KubeBlocks metric: mongodb_rs_members_health (0 = unhealthy, 1 = healthy)
        "mongodb_rs_members_health{app_kubernetes_io_instance=\"${local.app_label}\"} == 0" :

        rule_name == "mongodb_high_queued_operations" ?
        # KubeBlocks metric: mongodb_ss_globalLock_currentQueue (readers + writers)
        "(mongodb_ss_globalLock_currentQueue_readers{app_kubernetes_io_instance=\"${local.app_label}\"} + mongodb_ss_globalLock_currentQueue_writers{app_kubernetes_io_instance=\"${local.app_label}\"}) > ${lookup(rule_config, "threshold", 100)}" :

        rule_name == "mongodb_slow_queries" ?
        # KubeBlocks metric: mongodb_ss_opcounters (rate of operations)
        # Note: This is an approximation as KubeBlocks doesn't expose direct slow query metrics
        "rate(mongodb_ss_opcounters_total{app_kubernetes_io_instance=\"${local.app_label}\"}[5m]) > ${lookup(rule_config, "threshold_ms", 100)}" :

        "unknown_alert"
      )
      for = lookup(rule_config, "for_duration", "5m")
      labels = merge(
        local.common_labels,
        {
          severity   = lookup(rule_config, "severity", "warning")
          alert_type = rule_name
          cluster    = local.app_label
          namespace  = local.namespace_label
        }
      )
      annotations = {
        summary = (
          rule_name == "mongodb_down" ?
          "MongoDB {{ $labels.app_kubernetes_io_instance }} is down" :

          rule_name == "mongodb_high_connections" ?
          "MongoDB {{ $labels.app_kubernetes_io_instance }} connection usage is {{ $value | humanizePercentage }}" :

          rule_name == "mongodb_high_memory" ?
          "MongoDB {{ $labels.app_kubernetes_io_instance }} memory usage is {{ $value | humanize }}GB" :

          rule_name == "mongodb_replication_lag" ?
          "MongoDB {{ $labels.app_kubernetes_io_instance }} replication lag is {{ $value }}s" :

          rule_name == "mongodb_replica_unhealthy" ?
          "MongoDB replica member {{ $labels.member_idx }} ({{ $labels.member_state }}) is unhealthy" :

          rule_name == "mongodb_high_queued_operations" ?
          "MongoDB {{ $labels.app_kubernetes_io_instance }} has {{ $value }} queued operations" :

          rule_name == "mongodb_slow_queries" ?
          "MongoDB {{ $labels.app_kubernetes_io_instance }} has elevated operation rate: {{ $value }} ops/s" :

          "Unknown alert"
        )
        description = (
          rule_name == "mongodb_down" ?
          "MongoDB cluster {{ $labels.app_kubernetes_io_instance }} in namespace {{ $labels.namespace }} has been down for more than ${lookup(rule_config, "for_duration", "1m")}. Immediate action required." :

          rule_name == "mongodb_high_connections" ?
          "MongoDB connection usage has exceeded ${lookup(rule_config, "threshold", 80)}% for more than ${lookup(rule_config, "for_duration", "5m")}. Current: {{ $value | humanizePercentage }}. Consider scaling or optimizing connection pooling." :

          rule_name == "mongodb_high_memory" ?
          "MongoDB resident memory usage has exceeded ${lookup(rule_config, "threshold_gb", 3)}GB for more than ${lookup(rule_config, "for_duration", "5m")}. Current: {{ $value | humanize }}GB. Consider increasing memory limits." :

          rule_name == "mongodb_replication_lag" ?
          "MongoDB replication lag has exceeded ${lookup(rule_config, "threshold_seconds", 10)}s for more than ${lookup(rule_config, "for_duration", "2m")}. Current lag: {{ $value }}s. Check network connectivity and replica set health." :

          rule_name == "mongodb_replica_unhealthy" ?
          "MongoDB replica set member {{ $labels.member_idx }} in state {{ $labels.member_state }} has been unhealthy for more than ${lookup(rule_config, "for_duration", "1m")}. Check member status with rs.status()." :

          rule_name == "mongodb_high_queued_operations" ?
          "MongoDB has more than ${lookup(rule_config, "threshold", 100)} queued operations (readers + writers) for ${lookup(rule_config, "for_duration", "5m")}. Current: {{ $value }}. Database may be overloaded." :

          rule_name == "mongodb_slow_queries" ?
          "MongoDB operation rate is elevated at {{ $value }} ops/s for ${lookup(rule_config, "for_duration", "5m")}. Review query performance with db.currentOp() and consider adding indexes." :

          "Unknown alert description"
        )
        runbook_url = "https://github.com/apecloud/kubeblocks-addons/blob/main/examples/mongodb/alert-rules.yaml"
      }
    }
    if lookup(rule_config, "enabled", true)
  ]
}

# PrometheusRule resource for MongoDB monitoring
# Using any-k8s-resource to avoid plan-time CRD validation issues
module "prometheus_rule" {
  source = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"

  name         = local.name
  namespace    = var.instance.spec.prometheus_namespace
  release_name = "mongo-monitor-${var.instance_name}-${substr(var.environment.unique_name, 0, 8)}"

  data = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"

    metadata = {
      name      = local.name
      namespace = var.instance.spec.prometheus_namespace
      labels    = local.common_labels
    }

    spec = {
      groups = [
        {
          name     = "${var.instance_name}-mongodb-alerts"
          interval = "30s"
          rules    = local.alert_rules
        }
      ]
    }
  }

  advanced_config = {
    wait            = false # PrometheusRule doesn't need wait
    timeout         = 300   # 5 minutes
    cleanup_on_fail = true
    max_history     = 3
  }
}
