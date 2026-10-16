# Cloud Account — GCP Provider (Project-Scoped)

Configures the `google` and `google-beta` Terraform providers for one GCP
project. The module reads the service-account key of a GCP cloud account that
you linked in Facets. It gives other GCP modules the project, the region and
the credentials through the `@facets/gcp_cloud_account` output.

- **Cloud:** gcp
- **Resources created:** none (the module reads a secret and configures providers)
- **Output type:** `@facets/gcp_cloud_account`
- **Providers exposed:** `google`, `google-beta`

Use this module as the base of every GCP project. Network, cluster, node pool,
service and datastore modules on GCP use its output.

---

## Usage

```yaml
kind: cloud_account
flavor: gcp_provider
version: "1.0"
disabled: false
spec:
  cloud_account: ""   # select a linked GCP cloud account
  region: ""          # for example asia-south1
```

Both fields are override-only. Set them for each environment, so that each
environment can use a different account or region.

---

## Inputs

**None.** The module gets all of its data from `spec` and from the secret of
the linked cloud account.

## Spec

| Field | Required | Notes |
|-------|----------|-------|
| `cloud_account` | Yes | A linked GCP cloud account. The dropdown shows only accounts with `accountType=CLOUD` and `provider=GCP`. Override-only. |
| `region` | Yes | The GCP region for regional resources. The dropdown reads `/cc-ui/v1/dropdown/gcp/regions-v2`. Override-only. |

---

## Outputs — `@facets/gcp_cloud_account`

### Attributes

| Attribute | Description |
|-----------|-------------|
| `project_id` | The project of the service account, from the cloud account secret |
| `project` | The same value as `project_id`. It stays for backward compatibility |
| `credentials` | The service-account key JSON, base64-decoded (**secret**) |
| `region` | The `spec.region` value |

`secrets: [credentials]`.

### Providers exposed

| Provider | Source | Version | project | credentials |
|----------|--------|---------|---------|-------------|
| `google` | `hashicorp/google` | `>= 6.43.0` | `attributes.project` | `attributes.credentials` |
| `google-beta` | `hashicorp/google-beta` | `>= 6.43.0` | `attributes.project` | `attributes.credentials` |

---

## Notes

- **Link the cloud account first.** The module reads the key of an account
  that is already linked in Facets. It does not create a service account.
- **The secret fetch runs only in a Facets release.** `locals.tf` calls
  `secret-fetcher.py` from the Facets release runner through `data.external`.
  A plain `terraform plan` outside Facets cannot read the key.
- **The providers set a default project.** Modules that use these providers
  create resources in the project of the service account. For folders,
  projects and org policies, use `cloud_account/gcp_org_provider`.
- **No resources, no destroy risk.** The module only reads a secret and
  declares providers.
