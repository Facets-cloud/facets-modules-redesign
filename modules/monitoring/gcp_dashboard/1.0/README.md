# monitoring/gcp_dashboard/1.0

Creates a [Cloud Monitoring dashboard](https://cloud.google.com/monitoring/dashboards)
from a dashboard JSON body, so a dashboard lives in the blueprint next to the
resources it watches instead of being hand-built in the Console.

## Inputs

| Input | Type | Required | Purpose |
|---|---|---|---|
| `gcp_provider` | `@facets/gcp_cloud_account` | yes | Supplies the `google` provider and the target `project_id` |

## Spec

| Field | Type | Required | Notes |
|---|---|---|---|
| `display_name` | string | yes | Name in the Console dashboard list. Folded into the JSON body, so it always wins over any `displayName` inside `dashboard_json`. |
| `dashboard_json` | string | yes | Full Cloud Monitoring `Dashboard` resource as JSON — `mosaicLayout`, `dashboardFilters`, widgets. Omit `name`; the API assigns it. |

## Outputs — `@facets/gcp_monitoring_dashboard`

| Attribute | Notes |
|---|---|
| `project_id` | Project the dashboard was created in |
| `dashboard_id` | `projects/<project>/dashboards/<id>` |
| `display_name` | Echoes the spec field |
| `console_url` | Direct Console link |

## Example

```yaml
kind: monitoring
flavor: gcp_dashboard
version: "1.0"
disabled: false
inputs:
  gcp_provider: cloud_account/default
spec:
  display_name: Database Fleet
  dashboard_json: |
    {"mosaicLayout":{"columns":12,"tiles":[]}}
```

## Notes

- `dashboard_json` is passed through as-is apart from the `displayName` merge, so
  anything the Dashboard API accepts works here without a module change. That is
  deliberate: encoding a typed schema for every widget type would be a large
  surface for no gain.
- Generating the JSON with a script and pasting the result in is the intended
  workflow for large dashboards.
