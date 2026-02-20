# =============================================================================
# LOCAL COMPUTATIONS
# =============================================================================

locals {
  project_id = var.inputs.gcp_provider.attributes.project_id

  # Flatten channels for iteration
  channels = {
    for name, config in var.instance.spec.channels :
    name => {
      type         = config.type
      display_name = lookup(config, "display_name", "${var.instance_name}-${name}")
      enabled      = lookup(config, "enabled", true)
      labels       = merge(var.environment.cloud_tags, lookup(config, "labels", {}))
      # Type-specific fields
      email_address = lookup(config, "email_address", null)
      channel       = lookup(config, "channel", null)
      auth_token    = lookup(config, "auth_token", null)
      url           = lookup(config, "url", null)
      service_key   = lookup(config, "service_key", null)
    }
  }

  # Filter by type
  email_channels = {
    for k, v in local.channels : k => v if v.type == "email"
  }
  slack_channels = {
    for k, v in local.channels : k => v if v.type == "slack"
  }
  webhook_channels = {
    for k, v in local.channels : k => v if v.type == "webhook"
  }
  pagerduty_channels = {
    for k, v in local.channels : k => v if v.type == "pagerduty"
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
# EMAIL NOTIFICATION CHANNELS
# =============================================================================

resource "google_monitoring_notification_channel" "email" {
  for_each = local.email_channels

  project      = local.project_id
  display_name = each.value.display_name
  type         = "email"
  enabled      = each.value.enabled

  labels = {
    email_address = each.value.email_address
  }

  user_labels = each.value.labels

  depends_on = [google_project_service.monitoring]
}

# =============================================================================
# SLACK NOTIFICATION CHANNELS
# =============================================================================

resource "google_monitoring_notification_channel" "slack" {
  for_each = local.slack_channels

  project      = local.project_id
  display_name = each.value.display_name
  type         = "slack"
  enabled      = each.value.enabled

  labels = {
    channel_name = each.value.channel
  }

  sensitive_labels {
    auth_token = each.value.auth_token
  }

  user_labels = each.value.labels

  depends_on = [google_project_service.monitoring]
}

# =============================================================================
# WEBHOOK NOTIFICATION CHANNELS
# =============================================================================

resource "google_monitoring_notification_channel" "webhook" {
  for_each = local.webhook_channels

  project      = local.project_id
  display_name = each.value.display_name
  type         = "webhook_tokenauth"
  enabled      = each.value.enabled

  labels = {
    url = each.value.url
  }

  user_labels = each.value.labels

  depends_on = [google_project_service.monitoring]
}

# =============================================================================
# PAGERDUTY NOTIFICATION CHANNELS
# =============================================================================

resource "google_monitoring_notification_channel" "pagerduty" {
  for_each = local.pagerduty_channels

  project      = local.project_id
  display_name = each.value.display_name
  type         = "pagerduty"
  enabled      = each.value.enabled

  sensitive_labels {
    service_key = each.value.service_key
  }

  user_labels = each.value.labels

  depends_on = [google_project_service.monitoring]
}
