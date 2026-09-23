# Cloud Scheduler Job (GCP)

Provisions a **GCP Cloud Scheduler HTTP job** that fires on a cron schedule.
The job sends an HTTP request to any target URI — a Cloud Run job `:run` API
(authenticated with an OAuth token), or a Cloud Run service / generic HTTPS
endpoint (authenticated with an OIDC token). It enables the Cloud Scheduler API
on the project, then creates the job.

- **Cloud:** gcp
- **Resources created:** `google_project_service` (cloudscheduler), `google_cloud_scheduler_job`
- **Output type:** `@facets/cloud_scheduler_job`

---

## Architecture

```
   INPUT                                RESOURCES (main.tf)                    OUTPUT
   ┌────────────────────────┐          ┌─────────────────────────────┐
   │ gcp_provider           │          │ google_project_service      │
   │ @facets/gcp_cloud_account          │  "cloudscheduler.googleapis"│
   │  attributes.project_id │──project─►│  (enable API)               │
   │  attributes.region     │          └──────────────┬──────────────┘
   └────────────────────────┘                         │ depends_on
                                                       ▼
   spec.schedule ─────────────────►    ┌─────────────────────────────┐
   spec.target.uri / method / body     │ google_cloud_scheduler_job  │
   spec.auth (oauth XOR oidc) ─────────►│  http_target { ... }        │──► @facets/cloud_scheduler_job
   spec.retry_config ──────────────────►│  dynamic oauth_token        │    attributes: id, name,
   spec.time_zone / paused / ...       │  dynamic oidc_token         │    project_id, region,
                                        │  dynamic retry_config       │    resource_name, schedule,
                                        └─────────────────────────────┘    state
```

The job name is passed through the shared `name` utility module (limit 500,
`resource_type = "scheduler"`) to keep it within the length limit.

---

## Usage

```yaml
kind: cloud_scheduler
flavor: gcp
version: "1.0"
spec:
  schedule: "*/5 * * * *"
  time_zone: Etc/UTC
  paused: false
  attempt_deadline: 180s
  target:
    uri: https://example.com/hook
```

---

## Inputs

| Input | Type | Provider | Required | Description |
|-------|------|----------|----------|-------------|
| `gcp_provider` | `@facets/gcp_cloud_account` | google | Yes | Supplies `project_id` and `region` for the job. |

---

## Spec

| Field | Type | Required | Default | Notes |
|-------|------|----------|---------|-------|
| `schedule` | string | Yes | — | Cron expression for the schedule. |
| `target` | object | Yes | — | HTTP target for the job. |
| `target.uri` | string | Yes | — | Full URL — a Cloud Run job `:run` API URI, or a service/HTTPS URL. |
| `target.http_method` | enum | No | `POST` | One of GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS. |
| `target.body` | string | No | — | Request body (plain text; base64-encoded automatically). |
| `target.headers` | object | No | `{}` | HTTP headers to send (map of string). |
| `time_zone` | string | No | `Etc/UTC` | IANA time zone for the schedule. |
| `paused` | boolean | No | `false` | Whether the job is paused. |
| `attempt_deadline` | string | No | `180s` | Deadline for job attempts. |
| `description` | string | No | — | Human-readable description of the job. |
| `auth.oauth_service_account_email` | string | No | — | Service account for OAuth (Google APIs, e.g. Cloud Run job `:run`). |
| `auth.oauth_scope` | string | No | — | OAuth scope. |
| `auth.oidc_service_account_email` | string | No | — | Service account for OIDC (Cloud Run services / generic HTTPS). |
| `auth.oidc_audience` | string | No | — | OIDC token audience. |
| `retry_config.retry_count` | number | No | — | Number of retry attempts (0–5). |
| `retry_config.max_retry_duration` | string | No | — | Max duration for retries (e.g. 3600s). |
| `retry_config.min_backoff_duration` | string | No | — | Minimum backoff between retries (e.g. 5s). |
| `retry_config.max_backoff_duration` | string | No | — | Maximum backoff between retries (e.g. 3600s). |
| `retry_config.max_doublings` | number | No | — | Max number of backoff doublings (0–20). |

---

## Outputs — `@facets/cloud_scheduler_job`

Attributes set in `outputs.tf`:

| Attribute | Description |
|-----------|-------------|
| `id` | Cloud Scheduler job ID. |
| `name` | Job name (after the name-length utility). |
| `project_id` | Project the job runs in. |
| `region` | Region the job runs in. |
| `resource_name` | Job ID (same value as `id`). |
| `schedule` | The active cron schedule. |
| `state` | Job state reported by GCP. |

No interfaces are emitted.

---

## Notes

- **API enablement.** The module enables `cloudscheduler.googleapis.com` with
  `disable_on_destroy = false`, and the job `depends_on` it.
- **Auth is mutually exclusive.** The `oauth_token` block is added only when
  `auth.oauth_service_account_email` is set; the `oidc_token` block only when
  `auth.oidc_service_account_email` is set. Set at most one. With neither, the
  request is sent unauthenticated.
- **Body encoding.** `target.body` is base64-encoded automatically before being
  sent; pass plain text.
- **Retry config.** The `retry_config` block is emitted only when the
  `retry_config` object is present in the spec.
```
