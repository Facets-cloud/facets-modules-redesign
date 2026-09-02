# Cloud Account — GCP Org Provider (Organization-Scoped)

Configures an **organization-scoped GCP provider** for landing-zone modules
that operate above a single project — creating **folders, projects, and
org policies**. Like the project-scoped flavor it fetches a linked cloud
account's service-account key, but the providers it exposes carry **no default
project**. Instead they set a **billing/quota project** and
`user_project_override = true`, the combination the Resource Manager v3 and
Org Policy v2 APIs require.

- **Cloud:** gcp
- **Resources created:** none (reads a secret, configures providers)
- **Output type:** `@facets/gcp_org_account`
- **Providers exposed:** `google`, `google-beta` (org-scoped, quota-project billed)

---

## Architecture

```
   SPEC (operator provides)                 THIS module                        DOWNSTREAM (foundation)
   ┌──────────────────────────┐             ┌───────────────────────────┐      ┌──────────────────────┐
   │ cloud_account (linked)   │──┐          │ data.external secret-     │      │ folder / project /   │
   │ org_id                   │  │          │ fetcher.py → project, SA  │      │ org-policy modules   │
   │ billing_account          │  ├────────► │                           │      │ consuming the        │
   │ region                   │  │          │ configures providers:     │ ───► │ @facets/gcp_org_     │
   │ quota_project (optional) │  │          │  google       ┐  NO       │      │ account output +     │
   └──────────────────────────┘  │          │  google-beta  ┘  project  │      │ the google provider  │
                                 │          │   credentials  = SA       │      └──────────────────────┘
                                 │          │   billing_project =       │
                                 │          │       quota_project       │
                                 │          │   user_project_override = │
                                 │          │       true                │
                                 │          └────────────┬──────────────┘
                                 │                       ▼
                                 │             output: @facets/gcp_org_account
                                 │             attributes.org_id / .org_name / .billing_account
                                 └───────────► attributes.quota_project / .region / .project_id
                                               attributes.credentials (secret)
```

The `google` / `google-beta` provider mappings set:

- `credentials          = attributes.credentials`
- `billing_project      = attributes.quota_project`
- `user_project_override = attributes.user_project_override` (always `true`)

Note there is **no `project` mapping** — that is the defining difference from
`gcp_provider`, and it is what lets consumers create top-level org resources.

---

## Usage

```yaml
kind: cloud_account
flavor: gcp_org_provider
version: "1.0"
disabled: false
spec:
  cloud_account: ""                       # select a linked GCP cloud account
  region: asia-south1
  org_id: "123456789012"                  # numeric org ID, 10–14 digits
  billing_account: 000000-000000-000000   # BILLING-ACCOUNT-ID format
  quota_project: my-project               # optional; defaults to the SA's project
```

---

## Inputs

**None.** This module takes no module inputs. It sources everything from
`spec` and the linked cloud account's secret.

## Spec

| Field | Required | Notes |
|-------|----------|-------|
| `cloud_account` | Yes | Linked GCP cloud account. Typeable dropdown filtered to `accountType=CLOUD`, `provider=GCP`. Override-only. |
| `region` | Yes | GCP region for regional resources. Override-only. |
| `org_id` | Yes | Numeric GCP organization ID. Pattern `^[0-9]{10,14}$`. |
| `billing_account` | Yes | Billing account for projects created in this org. Pattern `^[A-F0-9]{6}-[A-F0-9]{6}-[A-F0-9]{6}$`. |
| `quota_project` | No | Existing project used for API quota and as `billing_project` on org-scoped calls. Defaults to the SA's own project when omitted. |

---

## Outputs — `@facets/gcp_org_account`

### Attributes (`outputs.tf` / `locals.tf`)

| Attribute | Description |
|-----------|-------------|
| `credentials` | Base64-decoded service-account key JSON (**secret**) |
| `project_id` | The SA's project from the fetched secret |
| `org_id` | The `spec.org_id` value |
| `org_name` | `organizations/<org_id>` — the full resource name |
| `billing_account` | The `spec.billing_account` value |
| `quota_project` | `spec.quota_project`, or the SA's project if omitted (see Notes) |
| `user_project_override` | Always `true` |
| `region` | The `spec.region` value |

`secrets: [credentials]`.

### Providers exposed

| Provider | Source | Version | credentials | billing_project | user_project_override | project |
|----------|--------|---------|-------------|-----------------|-----------------------|---------|
| `google` | `hashicorp/google` | `>= 6.43.0` | `attributes.credentials` | `attributes.quota_project` | `attributes.user_project_override` | *(none)* |
| `google-beta` | `hashicorp/google-beta` | `>= 6.43.0` | `attributes.credentials` | `attributes.quota_project` | `attributes.user_project_override` | *(none)* |

---

## Notes

- **Org-scoped, no default project — by design.** Folder, project, and
  org-policy creation must run without a pinned `project`. That is why this
  flavor omits the `project` provider mapping that `gcp_provider` sets.
- **`quota_project` fallback uses `coalesce`, not `lookup`.** `quota_project`
  is `optional(string)` in `variables.tf`, so when omitted Terraform
  materialises the attribute as **`null`** rather than absent. `lookup()` would
  find the key and return that null, so `locals.tf` uses
  `coalesce(try(spec.quota_project, null), <SA project>)` to actually apply the
  fallback. This matters: `user_project_override = true` with a **null**
  `billing_project` is the exact combination that makes Resource Manager v3 /
  Org Policy v2 return `403`.
- **Requires the custom output type.** `@facets/gcp_org_account` must exist in
  the control plane before the module validates or uploads.
- **No resources, no destroy risk.** The module only reads a secret and
  declares providers.
