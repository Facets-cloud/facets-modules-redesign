# GCP Alert Policy Module

## Overview

This Facets module creates **GCP Cloud Monitoring alert policies** using a simple YAML spec.
It supports **metric-based alerts** (including Cloud Run Job metrics), and is designed to pair
with the `notification_channel/gcp` module for routing alerts to email, Slack, PagerDuty, etc.

## Module Details

- **Intent:** `alert_policy`
- **Flavor:** `gcp`
- **Version:** `1.0`
- **Cloud:** GCP

## Inputs

| Input                 | Type                                   | Required | Description                                   |
|-----------------------|----------------------------------------|----------|-----------------------------------------------|
| `gcp_provider`        | `@facets/gcp_cloud_account`            | Yes      | GCP project and authentication                |
| `notification_channels` | `@facets/gcp_notification_channel_attributes` | Yes      | Notification channels for alert delivery      |

Typically, `notification_channels` comes from the
`modules/notification_channel/gcp/1.0` module.

## Outputs

| Output    | Type                    | Description                     |
|-----------|-------------------------|---------------------------------|
| `default` | `@facets/gcp_alert_policies` | Created GCP alert policies |

## Basic Configuration Shape

```yaml
kind: alert_policy
flavor: gcp
spec:
  policies:
    <policy-name>:
      display_name: "Human name for this alert policy"
      severity: CRITICAL | ERROR | WARNING
      documentation: |
        Optional markdown runbook / description.
      condition:
        type: metric_threshold | metric_absence
        metric_type: <GCP metric type>
        filter: <Monitoring filter expression>
        comparison: COMPARISON_GT
        threshold: 0
        duration: 60s
        aggregation:
          alignment_period: 60s
          per_series_aligner: ALIGN_SUM
      auto_close: "86400s"   # auto-close after 1 day
      labels:
        team: platform
```

## Example: Cloud Run Job Failure Alert

```yaml
kind: alert_policy
flavor: gcp
spec:
  policies:
    job-failure:
      display_name: Cloud Run Job Failure Alert
      severity: CRITICAL
      documentation: |
        Alerts when any Cloud Run Job task fails.
      condition:
        type: metric_threshold
        metric_type: run.googleapis.com/job/completed_task_attempt_count
        filter: 'resource.type="cloud_run_job" AND metric.labels.result="failed"'
        comparison: COMPARISON_GT
        threshold: 0
        duration: 60s
        aggregation:
          alignment_period: 60s
          per_series_aligner: ALIGN_COUNT
```

In a blueprint, you would typically:

1. Deploy Cloud Run Jobs (e.g. `cloud_run/gcp_job`, `cloud_run/gpu_job`).
2. Deploy `notification_channel/gcp` to create email/Slack/PagerDuty channels.
3. Deploy this `alert_policy/gcp` module, wired to those notification channels.
