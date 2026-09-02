# Artifact Registry — GCP (Container Image Repository)

Creates a single Google **Artifact Registry** repository in the selected project
for container images. Use it as the per-project, environment-specific registry
that services push to and pull from. Optional CMEK encrypts the repository;
optional cleanup policies age out or retain image versions.

- **Cloud:** gcp
- **Resources created:** one Artifact Registry repository
- **Output type:** `@facets/artifact_registry`

---

## Architecture

```
   INPUTS                                   RESOURCE (main.tf)                         OUTPUT
   ┌────────────────────────────┐           ┌───────────────────────────────────┐     ┌────────────────────┐
   │ cloud_account              │           │ google_artifact_registry_repository│     │ @facets/           │
   │  @facets/gcp_org_account   │──google─► │   "this"                          │     │  artifact_registry │
   │                            │           │   project / location / repo_id    │     │   repository_id    │
   │ project                    │           │   format = DOCKER                 │────►│   location         │
   │  @facets/gcp_project        │──project─►│   kms_key_name <= kms (optional)  │     │   registry_url     │
   │  (holds the repository)    │           │   docker_config.immutable_tags    │     └────────────────────┘
   │                            │           │   cleanup_policies (KEEP/DELETE)  │
   │ kms (optional)             │           └───────────────────────────────────┘
   │  @facets/gcp_kms            │─key CMEK
   └────────────────────────────┘
```

`registry_url` is composed as `<location>-docker.pkg.dev/<project_id>/<repository_id>`
— the base path services use to tag and push images.

---

## Usage

```yaml
kind: artifact_registry
flavor: gcp
version: "1.0"
spec:
  repository_id: my-app                 # immutable repository ID
  location: asia-south1
  format: DOCKER
  description: Application container images
  kms_key_name: artifacts               # key name in the optional kms input
  immutable_tags: false                 # true => tags can never be re-pointed
  cleanup_policies: []
```

With cleanup policies:

```yaml
spec:
  repository_id: my-app
  immutable_tags: true
  cleanup_policies:
    - id: delete-old
      action: DELETE
      older_than: 2592000s              # 30 days
    - id: keep-recent
      action: KEEP
      keep_count: 10
```

Wire the optional `kms` input to a `@facets/gcp_kms` output to encrypt the
repository with CMEK; `kms_key_name` selects which key from that key ring.

---

## Inputs

| Input | Type | Required | Purpose |
|-------|------|----------|---------|
| `cloud_account` | `@facets/gcp_org_account` | Yes | GCP org account; supplies the `google` provider. |
| `project` | `@facets/gcp_project` | Yes | Project that holds the repository; its `project_id` is in the registry URL. |
| `kms` | `@facets/gcp_kms` | No | When set, the repository is CMEK-encrypted with `key_ids[kms_key_name]`. |

---

## Spec

| Field | Required | Default | Notes |
|-------|----------|---------|-------|
| `repository_id` | Yes | — | Immutable repository ID. Pattern `^[a-z][a-z0-9_-]{1,61}[a-z0-9]$`. |
| `location` | No | `asia-south1` | Artifact Registry location. |
| `format` | No | `DOCKER` | Immutable repository format. Only `DOCKER` is allowed. |
| `description` | No | `""` | Human-readable repository description. |
| `kms_key_name` | No | `artifacts` | Key name from the `kms` input used for repository CMEK. |
| `immutable_tags` | No | `false` | DOCKER only. When true, an existing tag can never be re-pointed at different content. |
| `cleanup_policies` | No | `[]` | Optional cleanup policies. |
| `cleanup_policies[].id` | Yes | — | Policy identifier. |
| `cleanup_policies[].action` | Yes | — | `KEEP` or `DELETE`. |
| `cleanup_policies[].older_than` | No | `""` | Duration for DELETE policies (e.g. `2592000s`). Omitted when empty. |
| `cleanup_policies[].keep_count` | No | `0` | Versions to keep for KEEP policies. `0` omits the condition. |

---

## Outputs — `@facets/artifact_registry`

No interfaces. Attributes (from `outputs.tf`):

| Attribute | Description |
|-----------|-------------|
| `repository_id` | Repository ID. |
| `location` | Repository location. |
| `registry_url` | `<location>-docker.pkg.dev/<project_id>/<repository_id>` — the push/pull base path. |

---

## Notes

- **`format` and `repository_id` are immutable.** Both are enforced immutable by
  Artifact Registry; changing either replaces the repository.
- **`immutable_tags` is DOCKER-only and applied conditionally.** The
  `docker_config` block is emitted only when `format == "DOCKER"` and
  `immutable_tags` is true. Recommended for production, but incompatible with
  promotion schemes that MOVE a floating tag between digests; compatible with
  promoting by copying a digest into a new tag.
- **Cleanup policies are optional and per-condition.** A DELETE policy's
  `older_than` condition is emitted only when non-empty; a KEEP policy's
  `most_recent_versions` condition only when `keep_count` is non-zero.
- **CMEK is optional and conditional.** `kms_key_name` on the repository is set
  only when the `kms` input is wired; otherwise Google-managed keys are used.
