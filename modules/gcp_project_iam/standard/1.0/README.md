# GCP Project IAM — Standard

Grants **additive IAM role/member bindings** on an existing Google Cloud
project, and optionally configures **Data Access audit logging** per service.
Each binding is a single role granted to a single member, so this module never
takes ownership of the project's whole IAM policy — it only manages the exact
role/member pairs you list, leaving all other bindings untouched.

**Use case:** landing-zone / gcp-foundation IAM. Grant a group `roles/viewer`,
give a CI service account a role, or turn on audit logs for a busy service —
without risk of clobbering IAM that other modules or teams manage.

- **Clouds:** gcp
- **Resources created:** `google_project_iam_member` (one per role/member pair),
  `google_project_iam_audit_config` (one per service)
- **Output type:** `@facets/gcp_project_iam`

---

## Architecture

```
   INPUTS                                  RESOURCES (main.tf)                 OUTPUT
   ┌────────────────────────────┐          ┌──────────────────────────────┐
   │ cloud_account              │          │ google_project_iam_member     │
   │  @facets/gcp_org_account   │──google─►│  one per (role × member)      │
   │  (google provider creds)   │ provider │  ADDITIVE — non-authoritative │
   ├────────────────────────────┤          ├──────────────────────────────┤   @facets/
   │ project                    │          │ google_project_iam_audit_     │──►gcp_project_iam
   │  @facets/gcp_project       │──project─►│  config                      │
   │  .attributes.project_id    │   _id    │  one per service              │
   └────────────────────────────┘          │  AUTHORITATIVE per service    │
                                           └──────────────────────────────┘
        spec.bindings[]        ─────────────────► role/member pairs
        spec.audit_configs[]   ─────────────────► per-service audit_log_config
```

Bindings are flattened: each `{role, members[]}` entry fans out to one
`google_project_iam_member` per member, keyed by `"<role>|<member>"`.

---

## Usage

### Grant roles to members

```yaml
kind: gcp_project_iam
flavor: standard
version: "1.0"
spec:
  bindings:
    - role: roles/viewer
      members:
        - group:my-team@example.com
    - role: roles/browser
      members:
        - group:my-team@example.com
```

### Grant roles and enable Data Access audit logs

```yaml
kind: gcp_project_iam
flavor: standard
version: "1.0"
spec:
  bindings:
    - role: roles/viewer
      members:
        - group:my-team@example.com
        - serviceAccount:ci-sa@my-project.iam.gserviceaccount.com
  audit_configs:
    - service: storage.googleapis.com
      audit_log_types:
        - DATA_READ
        - DATA_WRITE
      exempted_members: []
    - service: secretmanager.googleapis.com
      audit_log_types:
        - DATA_READ
      exempted_members: []
```

Members must be **fully qualified**: `group:`, `serviceAccount:`, `user:`, etc.

---

## Inputs

| Input | Type | Required | Purpose |
|-------|------|----------|---------|
| `cloud_account` | `@facets/gcp_org_account` | Yes | Supplies the `google` provider credentials. |
| `project` | `@facets/gcp_project` | Yes | Target project; `attributes.project_id` is the project bindings are applied to. |

## Spec

| Field | Required | Notes |
|-------|----------|-------|
| `bindings` | Yes | List of `{role, members[]}`. Each fans out to one additive `google_project_iam_member` per member. `role` e.g. `roles/viewer`; `members` are fully-qualified IAM members (`minItems: 1`). |
| `audit_configs` | No (default `[]`) | List of `{service, audit_log_types[], exempted_members[]}`. Configures Data Access audit logging per service. Authoritative per service. |
| `audit_configs[].service` | Yes (within item) | GCP audit service name, e.g. `storage.googleapis.com`. `allServices` is accepted but authoritative for every service. |
| `audit_configs[].audit_log_types` | Yes (within item) | One or more of `ADMIN_READ`, `DATA_READ`, `DATA_WRITE` (`minItems: 1`). |
| `audit_configs[].exempted_members` | No | Members exempted from audit logging for the configured log types. |

---

## Outputs — `@facets/gcp_project_iam`

No interfaces. Attributes:

| Attribute | Description |
|-----------|-------------|
| `project_id` | The project the bindings were applied to. |
| `role_member_pairs` | List of `{role, member}` actually created (echoed from the `google_project_iam_member` resources). |

---

## Notes

- **Bindings are additive (non-authoritative).** The module uses
  `google_project_iam_member`, which manages only the exact role/member pairs
  listed. It never removes or overwrites bindings created by other tools, people,
  or modules on the same project. Removing an entry from `bindings` removes just
  that one grant.
- **Audit configs ARE authoritative per service.** `google_project_iam_audit_config`
  replaces the entire audit configuration for each named service. A `variables.tf`
  validation rejects duplicate `service` values, because a service may appear only
  once. Enable `DATA_READ`/`DATA_WRITE` deliberately — they are billed on ingestion
  volume and can be very large for busy services.
- **Validated audit log types.** A `variables.tf` validation rejects any
  `audit_log_types` value outside `ADMIN_READ`, `DATA_READ`, `DATA_WRITE`.
- **Idempotent keys.** Bindings are keyed by `"<role>|<member>"`, so listing the
  same pair twice collapses to one binding rather than erroring.
