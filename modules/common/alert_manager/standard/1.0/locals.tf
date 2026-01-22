locals {
  name = var.instance_name

  # Always deploy to prometheus namespace
  namespace = lookup(var.inputs.prometheus.attributes, "namespace", var.environment.namespace)

  # Transform receivers from spec into AlertmanagerConfig format
  receivers = [
    for receiver_name, receiver_config in var.instance.spec.receivers : {
      name = receiver_name

      # Slack configuration - only include if type is slack
      slackConfigs = receiver_config.type == "slack" && receiver_config.slack_config != null ? [
        {
          apiURL = {
            name = receiver_config.slack_config.api_url_secret
            key  = "url"
          }
          channel = receiver_config.slack_config.channel
          title   = lookup(receiver_config.slack_config, "title", "{{ .GroupLabels.alertname }}")
          text    = lookup(receiver_config.slack_config, "text", "{{ range .Alerts }}{{ .Annotations.summary }}\\n{{ end }}")
        }
      ] : null

      # PagerDuty configuration - only include if type is pagerduty
      pagerdutyConfigs = receiver_config.type == "pagerduty" && receiver_config.pagerduty_config != null ? [
        {
          serviceKey = {
            name = receiver_config.pagerduty_config.service_key_secret
            key  = "key"
          }
          severity = lookup(receiver_config.pagerduty_config, "severity", "critical")
        }
      ] : null

      # Email configuration - only include if type is email
      emailConfigs = receiver_config.type == "email" && receiver_config.email_config != null ? [
        {
          to        = receiver_config.email_config.to
          from      = receiver_config.email_config.from
          smarthost = receiver_config.email_config.smarthost
          authUsername = {
            name = receiver_config.email_config.auth_secret
            key  = "username"
          }
          authPassword = {
            name = receiver_config.email_config.auth_secret
            key  = "password"
          }
        }
      ] : null

      # Webhook configuration - only include if type is webhook
      webhookConfigs = receiver_config.type == "webhook" && receiver_config.webhook_config != null ? [
        {
          url = receiver_config.webhook_config.url
          httpConfig = {
            followRedirects = true
          }
        }
      ] : null
    }
  ]

  # Transform routes from spec into AlertmanagerConfig format
  routes = [
    for route_name, route_config in var.instance.spec.routes : {
      receiver = route_config.receiver
      matchers = [
        for label_name, label_value in route_config.matchers : {
          name      = label_name
          value     = label_value
          matchType = "="
        }
      ]
      continue       = lookup(route_config, "continue", false)
      groupBy        = lookup(route_config, "group_by", ["alertname"])
      groupWait      = lookup(route_config, "group_wait", "30s")
      groupInterval  = lookup(route_config, "group_interval", "5m")
      repeatInterval = lookup(route_config, "repeat_interval", "4h")
    }
  ]

  # Get the first route as the default route (required by AlertmanagerConfig)
  default_route = length(local.routes) > 0 ? local.routes[0] : null

  # Statistics for outputs
  receiver_count   = length(local.receivers)
  route_count      = length(local.routes)
  enabled_channels = join(", ", [for receiver_name, receiver_config in var.instance.spec.receivers : receiver_config.type])
}
