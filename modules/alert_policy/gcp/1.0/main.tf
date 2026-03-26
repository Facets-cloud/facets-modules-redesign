# =============================================================================
# LOCAL COMPUTATIONS
# =============================================================================

locals {
  project_id = var.inputs.gcp_provider.attributes.project_id

  # Get ALL notification channel names from input - alerts go to all channels
  all_channel_names = values(var.inputs.notification_channels.channel_names)

  # Process policies
  policies = {
    for name, policy in var.instance.spec.policies :
    name => {
      display_name  = policy.display_name
      enabled       = lookup(policy, "enabled", true)
      severity      = lookup(policy, "severity", "WARNING")
      documentation = lookup(policy, "documentation", null)
      combiner      = lookup(policy, "combiner", "OR")
      auto_close    = lookup(policy, "auto_close", "86400s")
      labels        = merge(var.environment.cloud_tags, lookup(policy, "labels", {}))

      # Condition config
      condition = {
        type         = lookup(policy.condition, "type", "metric_threshold")
        display_name = lookup(policy.condition, "display_name", "${policy.display_name} Condition")
        metric_type  = policy.condition.metric_type
        filter       = lookup(policy.condition, "filter", null)
        comparison   = lookup(policy.condition, "comparison", "COMPARISON_GT")
        threshold    = lookup(policy.condition, "threshold", 0)
        duration     = lookup(policy.condition, "duration", "60s")
        aggregation = lookup(policy.condition, "aggregation", {
          alignment_period     = "60s"
          per_series_aligner   = "ALIGN_SUM"
          cross_series_reducer = "REDUCE_SUM"
          group_by_fields      = []
        })
      }
    }
  }
}

# =============================================================================
# ENABLE REQUIRED APIS
# =============================================================================

resource "google_project_service" "monitoring" {
  project            = local.project_id
  service            = "monitoring.googleapis.com"
  disable_on_destroy = false
}

# =============================================================================
# ALERT POLICIES
# =============================================================================

resource "google_monitoring_alert_policy" "this" {
  for_each = local.policies

  project      = local.project_id
  display_name = each.value.display_name
  enabled      = each.value.enabled
  combiner     = each.value.combiner
  severity     = each.value.severity

  # Notification channels - automatically uses ALL channels from input
  notification_channels = local.all_channel_names

  # Documentation/Runbook
  dynamic "documentation" {
    for_each = each.value.documentation != null ? [1] : []
    content {
      content   = each.value.documentation
      mime_type = "text/markdown"
    }
  }

  # Alert condition
  conditions {
    display_name = each.value.condition.display_name

    # Metric threshold condition
    dynamic "condition_threshold" {
      for_each = each.value.condition.type == "metric_threshold" ? [1] : []
      content {
        filter          = each.value.condition.filter != null ? "metric.type=\"${each.value.condition.metric_type}\" AND ${each.value.condition.filter}" : "metric.type=\"${each.value.condition.metric_type}\""
        comparison      = each.value.condition.comparison
        threshold_value = each.value.condition.threshold
        duration        = each.value.condition.duration

        aggregations {
          alignment_period     = lookup(each.value.condition.aggregation, "alignment_period", "60s")
          per_series_aligner   = lookup(each.value.condition.aggregation, "per_series_aligner", "ALIGN_SUM")
          cross_series_reducer = lookup(each.value.condition.aggregation, "cross_series_reducer", "REDUCE_SUM")
          group_by_fields      = lookup(each.value.condition.aggregation, "group_by_fields", [])
        }
      }
    }

    # Metric absence condition
    dynamic "condition_absent" {
      for_each = each.value.condition.type == "metric_absence" ? [1] : []
      content {
        filter   = each.value.condition.filter != null ? "metric.type=\"${each.value.condition.metric_type}\" AND ${each.value.condition.filter}" : "metric.type=\"${each.value.condition.metric_type}\""
        duration = each.value.condition.duration

        aggregations {
          alignment_period     = lookup(each.value.condition.aggregation, "alignment_period", "60s")
          per_series_aligner   = lookup(each.value.condition.aggregation, "per_series_aligner", "ALIGN_SUM")
          cross_series_reducer = lookup(each.value.condition.aggregation, "cross_series_reducer", "REDUCE_SUM")
          group_by_fields      = lookup(each.value.condition.aggregation, "group_by_fields", [])
        }
      }
    }
  }

  # Alert strategy - auto close
  alert_strategy {
    auto_close = each.value.auto_close
  }

  user_labels = each.value.labels

  depends_on = [google_project_service.monitoring]
}
