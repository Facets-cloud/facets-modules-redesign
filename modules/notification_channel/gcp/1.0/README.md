# GCP Notification Channel Module

## Overview

This Facets module creates **GCP Cloud Monitoring notification channels** for alerts.
It supports **Email, Slack, Webhook, and PagerDuty** integrations in a single, declarative spec.

You typically use it together with alerting modules (for example `alert_rules/prometheus`) and
workload modules like `cloud_run/*` that emit metrics and alerts.

## Module Details

- **Intent:** `notification_channel`
- **Flavor:** `gcp`
- **Version:** `1.0`
- **Cloud:** GCP

## Features

- Manage multiple notification channels in **one module instance**
- Supports **four channel types**:
  - Email (`email`)
  - Slack (`slack`)
  - Webhook (`webhook`)
  - PagerDuty (`pagerduty`)
- Automatically enables the **Cloud Monitoring API** (`monitoring.googleapis.com`)
- Adds **environment labels** from `environment.cloud_tags` to channels for routing and cost allocation
- Exposes **channel IDs and names** for wiring into alert policies

## Dependencies (Inputs)

| Input          | Type                        | Required | Description                          |
|----------------|-----------------------------|----------|--------------------------------------|
| `gcp_provider` | `@facets/gcp_cloud_account` | Yes      | GCP project and authentication config |

The `gcp_provider` input supplies at least:

```yaml
inputs:
  gcp_provider:
    type: '@facets/gcp_cloud_account'
    providers:
      - google
```

## Outputs

| Output       | Type                                         | Description                                      |
|--------------|----------------------------------------------|--------------------------------------------------|
| `default`    | `@facets/gcp_notification_channels`          | Aggregated notification channels for this module |
| `attributes` | `@facets/gcp_notification_channel_attributes` | Project ID, channel IDs and channel names        |

The module internally computes:

- `project_id` – from `gcp_provider.attributes.project_id`
- `channel_ids` – map of your logical channel keys → GCP channel IDs
- `channel_names` – map of your logical channel keys → full GCP resource names

These are exposed via the Facets output types so that alerting modules
or blueprints can reference specific channels.

## Configuration Schema

The key part of the spec is the `channels` map.
Each key is a **channel ID** you choose (e.g. `ops-email`, `ops-slack`), and the value
is an object describing the channel.

### Top-level shape

```yaml
kind: notification_channel
flavor: gcp
spec:
  channels:
    <channel-name>:
      type: <email|slack|webhook|pagerduty>
      # plus type-specific fields
```

Each channel supports:

```yaml
spec:
  channels:
    my-channel:
      type: email | slack | webhook | pagerduty
      display_name: "Optional human name"   # defaults to key (my-channel)
      enabled: true                          # defaults to true
      labels:                                # optional user_labels
        team: platform
        service: my-api

      # Email-specific
      email_address: ops@example.com

      # Slack-specific
      channel: "#alerts"
      auth_token: ${secrets.SLACK_BOT_TOKEN}

      # Webhook-specific
      url: https://alerts.example.com/hook

      # PagerDuty-specific
      service_key: ${secrets.PD_SERVICE_KEY}
```

### Channel Types

#### Email

```yaml
spec:
  channels:
    ops-email:
      type: email
      email_address: ops@example.com
```

Creates a `google_monitoring_notification_channel` of type `email` with
`labels.email_address` set to the configured address.

#### Slack

```yaml
spec:
  channels:
    ops-slack:
      type: slack
      channel: "#alerts"
      auth_token: ${secrets.SLACK_BOT_TOKEN}
```

Creates a `google_monitoring_notification_channel` of type `slack` with:
- `labels.channel_name` set to the Slack channel
- `sensitive_labels.auth_token` set to the Slack bot token

#### Webhook

```yaml
spec:
  channels:
    ops-webhook:
      type: webhook
      url: https://alerts.example.com/hook
```

Creates a `google_monitoring_notification_channel` of type `webhook_tokenauth`
with `labels.url` set to the webhook URL.

#### PagerDuty

```yaml
spec:
  channels:
    ops-pagerduty:
      type: pagerduty
      service_key: ${secrets.PD_SERVICE_KEY}
```

Creates a `google_monitoring_notification_channel` of type `pagerduty` with
`sensitive_labels.service_key` set to the PagerDuty integration key.

## How it works with Cloud Run and Alert Rules

- **Cloud Run modules** (such as `cloud_run/gcp_job`, `cloud_run/gpu`, `cloud_run/gpu_job`)
  emit logs and metrics into Cloud Monitoring.
- **Alert rules modules** (such as `alert_rules/prometheus`) define **when** to alert.
- **This notification_channel module** defines **where** those alerts go:
  - Email on-call
  - Slack `#alerts` channel
  - PagerDuty service
  - Custom webhooks

A typical blueprint will:

1. Deploy workloads (e.g. Cloud Run services/jobs).
2. Deploy monitoring/alert rules.
3. Deploy this notification_channel module.
4. Wire alerting policies to the channels exported by this module.

## Example Blueprint Snippet

```yaml
modules:
  notification-channel:
    kind: notification_channel
    flavor: gcp
    spec:
      channels:
        ops-email:
          type: email
          email_address: ops@example.com
          labels:
            team: platform
            severity: critical
        ops-slack:
          type: slack
          channel: "#alerts"
          auth_token: ${secrets.SLACK_BOT_TOKEN}
        ops-pagerduty:
          type: pagerduty
          service_key: ${secrets.PD_SERVICE_KEY}
```

This creates three GCP Monitoring notification channels that can be reused
across multiple alerting policies and workloads.
