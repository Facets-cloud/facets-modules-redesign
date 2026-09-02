# GCP KMS — Standard (CMEK Key Ring)

Creates a Google Cloud KMS **key ring** and one or more **CMEK crypto keys** in a
single project, then grants selected Google **service agents** encrypt/decrypt
access on each key. Use it as the landing-zone source of customer-managed
encryption keys that datastores, buckets, GKE, Pub/Sub, and Secret Manager
reference for encryption at rest.

- **Cloud:** gcp
- **Resources created:** one key ring, N crypto keys, service-identity and
  per-key IAM grants
- **Output type:** `@facets/gcp_kms`

---

## Architecture

```
   INPUTS                                    RESOURCES (main.tf)                       OUTPUT
   ┌────────────────────────────┐            ┌──────────────────────────────────┐     ┌──────────────────┐
   │ cloud_account              │            │ google_kms_key_ring "this"       │     │ @facets/gcp_kms  │
   │  @facets/gcp_org_account   │──google──► │  name / location / project       │     │  keyring_id      │
   │  (google, google-beta)     │            └──────────────┬───────────────────┘     │  keyring_name    │
   │                            │                           │                         │  location        │
   │ project                    │            ┌──────────────▼───────────────────┐     │  key_ids{ }      │
   │  @facets/gcp_project        │──project──►│ google_kms_crypto_key "keys"     │────►│                  │
   │  (key ring project + PN)   │            │  for_each = spec.keys            │     └──────────────────┘
   │                            │            │  ENCRYPT_DECRYPT · rotation      │
   │ grantee_project (optional) │            │  version_template (algo, level)  │
   │  @facets/gcp_project        │            └──────────────┬───────────────────┘
   └────────────────────────────┘                           │
                                              ┌──────────────▼───────────────────┐
                                              │ google_project_service_identity  │  (google-beta)
                                              │  provisions each service agent   │
                                              └──────────────┬───────────────────┘
                                                             │ depends_on
                                              ┌──────────────▼───────────────────┐
                                              │ google_kms_crypto_key_iam_member │
                                              │  cryptoKeyEncrypterDecrypter to  │
                                              │  each service agent per key      │
                                              └──────────────────────────────────┘
```

Each key's `service_agents` list is expanded into one IAM grant per
(key × project number × service agent). The member email is built from a
curated service-agent pattern map in `locals.tf` (`sqladmin`, `storage`,
`pubsub`, `secretmanager`, `redis`, `compute`, `container`, `artifactregistry`).

---

## Usage

```yaml
kind: gcp_kms
flavor: standard
version: "1.0"
spec:
  keyring_name: my-keyring
  location: asia-south1
  keys:
    - name: cloudsql
      purpose: ENCRYPT_DECRYPT
      rotation_period: 7776000s      # 90 days
      protection_level: SOFTWARE
      service_agents:
        - sqladmin
      grant_project_numbers: []      # empty => grantee_project / key ring project
    - name: storage
      service_agents:
        - storage
    - name: gke
      service_agents:
        - compute
        - container
    - name: pubsub
      service_agents:
        - pubsub
```

`grant_project_numbers` lets a key grant service agents in **other** projects
(cross-project CMEK). Leave it empty to grant the optional `grantee_project`
input, falling back to the key ring's own project.

---

## Inputs

| Input | Type | Required | Purpose |
|-------|------|----------|---------|
| `cloud_account` | `@facets/gcp_org_account` | Yes | GCP org account; supplies the `google` and `google-beta` providers. |
| `project` | `@facets/gcp_project` | Yes | Project that owns the key ring; its `project_number` is the default grant target. |
| `grantee_project` | `@facets/gcp_project` | No | When set, its `project_number` is the default grant target instead of the key ring project. |

---

## Spec

| Field | Required | Default | Notes |
|-------|----------|---------|-------|
| `keyring_name` | Yes | — | Immutable key ring name. |
| `location` | No | `asia-south1` | KMS location. Must match the data location for CMEK use. |
| `keys` | Yes | — | List of CMEK crypto keys to create. |
| `keys[].name` | Yes | — | Immutable crypto key name. |
| `keys[].purpose` | No | `ENCRYPT_DECRYPT` | Crypto key purpose. |
| `keys[].rotation_period` | No | `7776000s` | Rotation period (e.g. `7776000s` = 90 days). |
| `keys[].protection_level` | No | `SOFTWARE` | Protection level for generated key versions. |
| `keys[].service_agents` | No | `[]` | Short service-agent names to grant on this key. Allowed: `sqladmin`, `storage`, `pubsub`, `secretmanager`, `redis`, `compute`, `container`, `artifactregistry`. |
| `keys[].grant_project_numbers` | No | `[]` | Project numbers whose service agents receive the grant. Empty => grantee/key-ring project number. |

---

## Outputs — `@facets/gcp_kms`

No interfaces. Attributes (from `outputs.tf`):

| Attribute | Description |
|-----------|-------------|
| `keyring_id` | Full key ring resource ID. |
| `keyring_name` | Key ring name. |
| `location` | Key ring location. |
| `key_ids` | Map of crypto key name → full crypto key resource ID. Consumers (log sink, artifact registry) index this map by key name for CMEK. |

---

## Notes

- **Keys and key ring are destroy-protected.** `google_kms_crypto_key` carries
  `prevent_destroy = true`; key rings and keys cannot be deleted in GCP anyway.
  Removing a key from `spec.keys` will fail the plan rather than delete it.
- **Unknown service agent = hard failure.** A key ring `precondition` rejects any
  `service_agents` name not in the curated map and lists the allowed names.
- **Service identities are provisioned first.** For service-identity-mode agents,
  `google_project_service_identity` (google-beta) creates the agent, and the IAM
  member `depends_on` it so the grant applies in one pass.
- **Member emails come from the pattern map, not a data read.** This keeps
  existing IAM members known at plan time when new project grants are added.
- **Rotation applies to `ENCRYPT_DECRYPT` keys** via `rotation_period` on the
  key with a `GOOGLE_SYMMETRIC_ENCRYPTION` version template.
