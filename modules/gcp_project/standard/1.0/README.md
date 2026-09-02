# GCP Project

Creates a single Google Cloud **project** under a folder, attaches a billing
account, enables the requested APIs, and hardens the Google-managed default
service accounts. Use it as the landing-zone unit that holds real workloads. It
emits a `@facets/gcp_project` output that downstream infrastructure targets.

- **Clouds:** gcp
- **Resources created:** `google_project`, `google_project_service` (per API),
  `time_sleep`, `google_project_default_service_accounts`
- **Output type:** `@facets/gcp_project`

---

## Architecture

```
   INPUTS                                THIS module (main.tf)                    OUTPUT
   ┌──────────────────────────┐
   │ cloud_account            │ billing_account
   │  @facets/gcp_org_account │ ──────────────┐
   │  attributes              │               │
   └──────────────────────────┘               ▼
                                    ┌───────────────────────────┐
   ┌──────────────────────────┐     │ google_project.this       │       @facets/gcp_project
   │ parent_folder            │────►│  project_id / name        │ ────► attributes:
   │  @facets/gcp_folder      │     │  folder_id  billing       │         project_id
   │  attributes.folder_id    │folder  auto_create_network=false│         project_number
   └──────────────────────────┘     └────────────┬──────────────┘         project_name
                                                 │                         folder_id
                                                 ▼                         enabled_apis
                                    ┌───────────────────────────┐
                                    │ google_project_service    │  (one per activate_apis)
                                    └────────────┬──────────────┘
                                                 ▼
                                    ┌───────────────────────────┐
                                    │ time_sleep (60s API prop.) │
                                    └────────────┬──────────────┘
                                                 ▼
                                    ┌───────────────────────────┐
                                    │ google_project_default_    │
                                    │ service_accounts (harden)  │
                                    └───────────────────────────┘
```

---

## Usage

```yaml
kind: gcp_project
flavor: standard
version: "1.0"
spec:
  project_id: my-app-stage          # globally unique, immutable
  display_name: My App Stage
  labels: {}
  activate_apis:
    - serviceusage.googleapis.com
    - cloudresourcemanager.googleapis.com
  default_sa_action: DEPRIVILEGE
  deletion_policy: PREVENT
```

The `parent_folder` input selects the folder the project is created under.

---

## Inputs

| Name | Type | Required | Purpose |
|------|------|----------|---------|
| `cloud_account` | `@facets/gcp_org_account` (provider `google`) | Yes | GCP org credentials and provider. Supplies the `billing_account` attached to the project. |
| `parent_folder` | `@facets/gcp_folder` | Yes | Folder the project is created under (`attributes.folder_id`). |

---

## Spec

| Field | Required | Default | Notes |
|-------|----------|---------|-------|
| `project_id` | Yes | — | Globally unique, immutable project id. Pattern `^[a-z][a-z0-9-]{4,28}[a-z0-9]$`. |
| `display_name` | Yes | — | Human-readable project name. |
| `labels` | No | `{}` | Labels merged with the environment's cloud tags. |
| `activate_apis` | No | `[]` | Google APIs to enable, one `google_project_service` each. |
| `default_sa_action` | No | `DEPRIVILEGE` | Action on default service accounts. One of `DEPRIVILEGE`, `DISABLE`, `DELETE`, `NONE`. |
| `deletion_policy` | No | `PREVENT` | Project deletion behavior. One of `PREVENT`, `DELETE`, `ABANDON`. |

---

## Outputs — `@facets/gcp_project`

No interfaces. Attributes:

| Attribute | Description |
|-----------|-------------|
| `project_id` | The project id. |
| `project_number` | Numeric project number (string). |
| `project_name` | Full resource name (`projects/<project_id>`). |
| `folder_id` | Parent folder id. |
| `enabled_apis` | List of APIs enabled by this module (the `activate_apis` set). |

---

## Notes

- **`deletion_policy` defaults to `PREVENT`.** The project cannot be destroyed
  by Terraform until this is changed to `DELETE` (or `ABANDON` to drop it from
  state without deleting the GCP project).
- **`auto_create_network = false`.** No default VPC is created — bring your own
  network module.
- **Labels are merged**, not replaced: environment `cloud_tags` first, then
  `spec.labels` on top.
- **API enablement is one-way at destroy time.** `disable_on_destroy = false`
  and `disable_dependent_services = false`, so removing an API from
  `activate_apis` leaves it enabled on the project.
- **60s propagation wait.** A `time_sleep` gives newly enabled APIs time to
  propagate before the default-SA hardening runs.
- **Default-SA hardening** uses `restore_policy = "REVERT_AND_IGNORE_FAILURE"`,
  so on removal it attempts to restore the accounts and ignores failures.
