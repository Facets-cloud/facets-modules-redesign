# GCP Organization Policy

Applies one or more Google Cloud **Organization Policy v2** constraints at
**folder scope**. Use it to set guardrails on a landing-zone folder — restrict
resource locations, block external IPs, require private-IP Cloud SQL, and so on.
Supports both boolean and list constraints. It emits a `@facets/gcp_org_policy`
output recording which constraints were applied.

- **Clouds:** gcp
- **Resources created:** one `google_org_policy_policy` per constraint
- **Scope:** folder only (`folders/<id>`), derived from the `parent_folder` input
- **Output type:** `@facets/gcp_org_policy`

---

## Architecture

```
   INPUTS                                THIS module (main.tf)               OUTPUT
   ┌──────────────────────────┐
   │ cloud_account            │  provider (google)
   │  @facets/gcp_org_account │ ───────────────┐
   └──────────────────────────┘                │
                                                ▼
   ┌──────────────────────────┐     ┌──────────────────────────────┐   @facets/gcp_org_policy
   │ parent_folder            │────►│ google_org_policy_policy.this │─► attributes:
   │  @facets/gcp_folder      │ folders/<id>  (one per constraint)  │     applied_constraints
   │  attributes.folder_id    │     │  name = <parent>/policies/<c> │     parent
   └──────────────────────────┘     │  spec.rules { boolean | list }│
                                    └──────────────────────────────┘
        spec.constraints[] ─────────────────► for_each keyed by constraint
```

Each list rule resolves to exactly one of `deny_all`, `allow_all`, or a
`values{}` block (`allowed_values` / `denied_values`). Boolean rules set
`enforce` only.

---

## Usage

```yaml
kind: gcp_org_policy
flavor: standard
version: "1.0"
spec:
  constraints:
    # LIST — restrict resource locations
    - constraint: gcp.resourceLocations
      rule_type: list
      allowed_values:
        - in:asia-south1-locations
      inherit_from_parent: true

    # LIST — deny every value (block all external IPs). Use deny_all,
    # NOT denied_values: ["all"] (see Notes).
    - constraint: compute.vmExternalIpAccess
      rule_type: list
      deny_all: true
      inherit_from_parent: true

    # BOOLEAN — enforce a guardrail
    - constraint: sql.restrictPublicIp
      rule_type: boolean
      enforce: true

    # LIST — require CMEK for specific services
    - constraint: gcp.restrictNonCmekServices
      rule_type: list
      denied_values:
        - sqladmin.googleapis.com
        - storage.googleapis.com
      inherit_from_parent: true
```

---

## Inputs

| Name | Type | Required | Purpose |
|------|------|----------|---------|
| `cloud_account` | `@facets/gcp_org_account` (provider `google`) | Yes | GCP org credentials and provider. |
| `parent_folder` | `@facets/gcp_folder` | Yes | Folder the policies apply to (`attributes.folder_id` → `folders/<id>`). |

---

## Spec

Top-level field:

| Field | Required | Default | Notes |
|-------|----------|---------|-------|
| `constraints` | Yes | `[]` | List of constraints to manage on the folder. Each entry as below. |

Per-constraint fields:

| Field | Required | Default | Notes |
|-------|----------|---------|-------|
| `constraint` | Yes | — | Constraint name, e.g. `gcp.resourceLocations`. Keys the `for_each`, so must be unique in the list. |
| `rule_type` | Yes | — | `boolean` or `list`. |
| `enforce` | No | `false` | Boolean constraints only. Enforcement value (`TRUE`/`FALSE`). |
| `deny_all` | No | `false` | List only. Deny every value. Mutually exclusive with `allow_all` and with `allowed_values`/`denied_values`. |
| `allow_all` | No | `false` | List only. Allow every value. Mutually exclusive with `deny_all` and with `allowed_values`/`denied_values`. |
| `allowed_values` | No | `null` | List only. Explicit allowed identifiers. |
| `denied_values` | No | `null` | List only. Explicit denied identifiers. |
| `inherit_from_parent` | No | `true` | List only. Whether the folder policy inherits parent rules. Omitted (null) for boolean constraints — GCP rejects it there. |

---

## Outputs — `@facets/gcp_org_policy`

No interfaces. Attributes:

| Attribute | Description |
|-----------|-------------|
| `applied_constraints` | List of constraint names that were applied (the `for_each` keys). |
| `parent` | The scope the policies were applied to (`folders/<id>`). |

---

## Notes

- **Folder-scoped only.** `parent` is hardcoded to `folders/<folder_id>` from the
  `parent_folder` input. This module does not do org-level or project-level
  policies.
- **No magic `"all"` string.** In GCP list constraints, values are real
  identifiers (VM paths, API service names, etc.). A literal `"all"` in
  `allowed_values`/`denied_values` matches nothing — the policy shows ACTIVE but
  enforces nothing. A `precondition` in `main.tf` fails the apply if `"all"`
  appears in either list. Use `deny_all` / `allow_all` instead.
- **`deny_all` and `allow_all` are mutually exclusive.** Setting both on one
  constraint fails a `precondition` at plan time.
- **`inherit_from_parent` is auto-omitted for boolean constraints.** GCP errors
  (`Cannot set InheritFromParent for boolean constraints`) if it is sent, so the
  module passes `null` there and only applies it to list rules.
- **Constraint name is the `for_each` key** — each constraint may appear once per
  instance. Repeat the module for policies on a different folder.
- **`enforce` / `deny_all` / `allow_all` carry explicit `false` defaults** by
  design; a null there would be a hard Terraform error in the ternaries that read
  them.
