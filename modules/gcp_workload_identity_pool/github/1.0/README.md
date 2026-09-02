# GCP Workload Identity Pool — GitHub

Creates a **Google Cloud Workload Identity Federation** pool and a **GitHub
Actions OIDC provider**, then grants selected GitHub repositories the right to
impersonate a service account. This is **keyless CI auth**: GitHub Actions
workflows exchange their OIDC token for short-lived GCP credentials, with no
long-lived service-account JSON key stored in GitHub.

- **Clouds:** gcp
- **Resources created:** `google_iam_workload_identity_pool`,
  `google_iam_workload_identity_pool_provider`,
  `google_service_account_iam_member` (one per repository)
- **Output type:** `@facets/gcp_workload_identity_pool`

---

## Architecture

```
   INPUTS                            RESOURCES (main.tf)                       OUTPUT
   ┌──────────────────────────┐      ┌─────────────────────────────────────┐
   │ cloud_account            │      │ google_iam_workload_identity_pool     │
   │  @facets/gcp_org_account │──►───│  "GitHub Actions" pool                │
   │  (google provider)       │google│                                       │
   ├──────────────────────────┤ prov ├─────────────────────────────────────┤ @facets/
   │ project                  │      │ ..._pool_provider "github"            │─►gcp_workload_
   │  @facets/gcp_project     │──►───│  oidc issuer = token.actions.github…  │ identity_pool
   │  .project_id / _number   │      │  attribute_condition (repo_owner==org)│
   └──────────────────────────┘      ├─────────────────────────────────────┤
                                     │ google_service_account_iam_member     │
     spec.repositories[]  ──────────►│  role = roles/iam.workloadIdentityUser│
     spec.service_account_email ────►│  member = principalSet://.../repo     │
                                     │  one per repository                   │
                                     └─────────────────────────────────────┘
```

### OIDC trust chain (how a repo reaches the SA)

```
  GitHub Actions job in owner/repo
        │  presents OIDC token (issuer token.actions.githubusercontent.com)
        ▼
  Pool provider "github"
        │  attribute_condition gates it:  assertion.repository_owner == "<github_org>"
        │  attribute_mapping:  attribute.repository = assertion.repository
        ▼
  principalSet://iam.googleapis.com/projects/<project_number>/locations/global/
      workloadIdentityPools/<pool_id>/attribute.repository/<owner/repo>
        │  holds roles/iam.workloadIdentityUser on the SA
        ▼
  impersonates  spec.service_account_email   → short-lived GCP credentials
```

Only repositories listed in `spec.repositories` get the `workloadIdentityUser`
binding, and the provider condition additionally restricts to `github_org`, so
both org *and* explicit repo must match.

---

## Usage

```yaml
kind: gcp_workload_identity_pool
flavor: github
version: "1.0"
spec:
  workload_identity_pool_id: github        # immutable, default "github"
  provider_id: github-oidc                 # immutable, default "github-oidc"
  github_org: my-org
  attribute_condition: ""                   # empty → restrict to github_org
  service_account_email: ci-sa@my-project.iam.gserviceaccount.com
  repositories:
    - my-org/my-repo
```

Leave `attribute_condition` empty to auto-restrict to
`assertion.repository_owner == "my-org"`. Set it to a custom CEL expression to
override that default entirely.

---

## Inputs

| Input | Type | Required | Purpose |
|-------|------|----------|---------|
| `cloud_account` | `@facets/gcp_org_account` | Yes | Supplies the `google` provider credentials. |
| `project` | `@facets/gcp_project` | Yes | Hosts the pool; provides `project_id` and `project_number` (the number is used in the `principalSet://` member). |

## Spec

| Field | Required | Notes |
|-------|----------|-------|
| `workload_identity_pool_id` | No | Immutable pool ID. Pattern `^[a-z][a-z0-9-]{2,30}[a-z0-9]$`. Default `github`. |
| `provider_id` | No | Immutable provider ID. Same pattern. Default `github-oidc`. |
| `github_org` | Yes | GitHub org/owner allowed by the default attribute condition. |
| `attribute_condition` | No | Custom CEL condition. Empty → restrict to `github_org` via `assertion.repository_owner`. |
| `service_account_email` | Yes | SA the repositories may impersonate. Pattern enforces `<id>@<project>.iam.gserviceaccount.com`. |
| `repositories` | Yes | GitHub repos (`owner/repo`) granted `workloadIdentityUser`. `minItems: 1`. |

---

## Outputs — `@facets/gcp_workload_identity_pool`

No interfaces. Attributes:

| Attribute | Description |
|-----------|-------------|
| `pool_name` | Full resource name of the pool. |
| `pool_id` | The pool's `workload_identity_pool_id`. |
| `provider_id` | The provider ID. |
| `provider_resource_name` | `<pool_name>/providers/<provider_id>` — the value GitHub Actions references as the WIF provider. |

---

## Notes

- **Keyless CI auth.** The provider trusts GitHub's OIDC issuer
  (`https://token.actions.githubusercontent.com`). Workflows authenticate with
  their federated token — no service-account key is created or stored.
- **Two layers of restriction.** The provider's `attribute_condition` gates by
  org (`repository_owner`); the per-repo `google_service_account_iam_member`
  bindings gate by exact `owner/repo`. A workflow must satisfy both to
  impersonate the SA.
- **Default vs custom condition.** If `attribute_condition` is blank (after
  trim), the module builds `assertion.repository_owner == "<github_org>"`. Any
  non-empty value replaces that default wholesale — you own the full CEL.
- **`attribute_mapping`.** Maps `google.subject` = `assertion.sub` and
  `attribute.repository` = `assertion.repository`; the latter is what the
  `principalSet://.../attribute.repository/<owner/repo>` member matches on.
- **Immutable IDs.** `workload_identity_pool_id` and `provider_id` cannot be
  changed in place — changing either recreates the resource.
- **Repository bindings are additive.** Each repo gets its own
  `google_service_account_iam_member`; removing a repo removes just its binding.
