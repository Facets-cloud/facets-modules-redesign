# =============================================================================
# OUTPUTS - Facets uses local.output_attributes and local.output_interfaces
# =============================================================================

locals {
  # Collect all channel IDs and names
  all_channel_ids = merge(
    { for k, v in google_monitoring_notification_channel.email : k => v.id },
    { for k, v in google_monitoring_notification_channel.slack : k => v.id },
    { for k, v in google_monitoring_notification_channel.webhook : k => v.id },
    { for k, v in google_monitoring_notification_channel.pagerduty : k => v.id }
  )

  all_channel_names = merge(
    { for k, v in google_monitoring_notification_channel.email : k => v.name },
    { for k, v in google_monitoring_notification_channel.slack : k => v.name },
    { for k, v in google_monitoring_notification_channel.webhook : k => v.name },
    { for k, v in google_monitoring_notification_channel.pagerduty : k => v.name }
  )

  output_attributes = {
    project_id    = local.project_id
    channel_ids   = local.all_channel_ids
    channel_names = local.all_channel_names
  }

  output_interfaces = {}
}
