# Alertmanager Receiver Module

Configure notification receivers and routing rules for Prometheus Alertmanager.

## Overview

This module deploys AlertmanagerConfig CRD to dynamically configure where alerts are sent based on label matching. Supports multiple notification channels including Slack, PagerDuty, Email, and custom webhooks.

## Features

- **Multiple Receiver Types**: Slack, PagerDuty, Email, Webhooks
- **Label-Based Routing**: Route alerts based on severity, team, service, or any label
- **Secret Management**: Uses Kubernetes secrets for sensitive credentials
- **Flexible Routing**: Support for grouped notifications, wait times, and repeat intervals
- **Continue Matching**: Route alerts to multiple receivers simultaneously

## Prerequisites

1. **Kubernetes Secrets**: Create secrets for receiver credentials before deploying this module

```bash
# Slack webhook secret
kubectl create secret generic slack-webhook-secret \
  --from-literal=url=https://hooks.slack.com/services/YOUR/WEBHOOK/URL \
  -n monitoring

# PagerDuty integration key secret
kubectl create secret generic pagerduty-key-secret \
  --from-literal=key=YOUR_PAGERDUTY_INTEGRATION_KEY \
  -n monitoring

# SMTP authentication secret
kubectl create secret generic smtp-auth-secret \
  --from-literal=username=your-smtp-username \
  --from-literal=password=your-smtp-password \
  -n monitoring
```

2. **Prometheus Operator**: Alertmanager with Prometheus Operator must be deployed

## Usage

See facets.yaml for full spec schema and configuration options.

## Examples

### Example 1: Slack Notifications for Platform Team

```yaml
kind: alert_manager
flavor: standard
spec:
  receivers:
    slack_platform:
      type: slack
      slack_config:
        api_url_secret: slack-webhook-secret
        channel: "#platform-alerts"
        title: "{{ .GroupLabels.alertname }}"
        text: "{{ range .Alerts }}{{ .Annotations.summary }}\n{{ end }}"

  routes:
    platform_alerts:
      receiver: slack_platform
      matchers:
        team: platform
      group_by:
        - alertname
        - service
```

### Example 2: Critical Alerts to PagerDuty, Warnings to Slack

```yaml
kind: alert_manager
flavor: standard
spec:
  receivers:
    pagerduty_oncall:
      type: pagerduty
      pagerduty_config:
        service_key_secret: pagerduty-key-secret
        severity: critical

    slack_warnings:
      type: slack
      slack_config:
        api_url_secret: slack-webhook-secret
        channel: "#warnings"

  routes:
    critical_to_pagerduty:
      receiver: pagerduty_oncall
      matchers:
        severity: critical
      group_wait: "10s"
      repeat_interval: "1h"

    warnings_to_slack:
      receiver: slack_warnings
      matchers:
        severity: warning
      group_wait: "5m"
      repeat_interval: "4h"
```

### Example 3: Multi-Team Routing with Continue

```yaml
kind: alert_manager
flavor: standard
spec:
  receivers:
    pagerduty_platform:
      type: pagerduty
      pagerduty_config:
        service_key_secret: pagerduty-platform-key
        severity: critical

    slack_platform:
      type: slack
      slack_config:
        api_url_secret: slack-platform-webhook
        channel: "#platform-alerts"

    slack_devops:
      type: slack
      slack_config:
        api_url_secret: slack-devops-webhook
        channel: "#devops"

  routes:
    # Critical platform alerts go to PagerDuty AND Slack
    platform_critical:
      receiver: pagerduty_platform
      matchers:
        team: platform
        severity: critical
      continue: true  # Continue to next route

    platform_slack:
      receiver: slack_platform
      matchers:
        team: platform
      continue: false

    # DevOps team gets their own alerts
    devops_alerts:
      receiver: slack_devops
      matchers:
        team: devops
```

### Example 4: Email Notifications

```yaml
kind: alert_manager
flavor: standard
spec:
  receivers:
    email_admins:
      type: email
      email_config:
        to: admins@example.com
        from: alertmanager@example.com
        smarthost: smtp.gmail.com:587
        auth_secret: smtp-auth-secret

  routes:
    database_alerts:
      receiver: email_admins
      matchers:
        alert_type: database
        severity: critical
```

### Example 5: Custom Webhook

```yaml
kind: alert_manager
flavor: standard
spec:
  receivers:
    custom_webhook:
      type: webhook
      webhook_config:
        url: https://webhook.example.com/alerts
        http_method: POST

  routes:
    all_alerts:
      receiver: custom_webhook
      matchers:
        alertname: ".*"  # Match all alerts
```

## Routing Logic

Routes are evaluated in order. The first matching route (based on label matchers) is used unless `continue: true` is set.

**Routing Flow**:
1. Alert fires in Prometheus
2. Alertmanager evaluates routes in order
3. First route where ALL matchers match is selected
4. If `continue: true`, evaluation continues to next route
5. Alert sent to receiver(s)

## Label Matchers

Common labels to match on:
- `severity`: critical, warning, info
- `team`: platform, devops, etc.
- `alert_type`: From alert_rules module
- `alertname`: Specific alert name
- `namespace`: Kubernetes namespace
- `service`: Service name

## Notification Grouping

- **group_by**: Group alerts by these labels before sending (reduces notification spam)
- **group_wait**: Wait this long before sending first notification for a new group
- **group_interval**: Wait this long before sending notification about new alerts in existing group
- **repeat_interval**: Wait this long before re-sending for unresolved alerts

## Requirements

- Kubernetes cluster with Prometheus Operator
- Alertmanager deployed (via prometheus module)
- Kubernetes secrets for receiver credentials

## Related Modules

- `alert_rules/prometheus`: Define WHAT alerts to fire
- `alert_manager/standard`: Define WHERE alerts go (this module)
- `prometheus/k8s_standard`: Deploy Prometheus + Alertmanager stack

## Documentation

This README will be auto-generated by raptor during module upload.
