# AWS IAM OIDC Provider for GKE

Registers a **GKE cluster's OIDC issuer as an AWS IAM OpenID Connect identity
provider**. Once registered, GKE workloads presenting a projected service-account
token can call AWS STS `AssumeRoleWithWebIdentity` to assume AWS IAM roles —
cross-cloud workload identity from Google Kubernetes Engine into AWS.

- **Cloud:** aws
- **Resources created:** `aws_iam_openid_connect_provider` (plus a `tls_certificate` data source)
- **Output type:** `@facets/aws_iam_oidc_provider`

---

## Architecture

```
   INPUTS                                   RESOURCES (main.tf)                    OUTPUT
   ┌──────────────────────────────┐
   │ cloud_account                │
   │ @facets/aws_cloud_account    │──(aws provider: where the OIDC provider is created)
   └──────────────────────────────┘
                                            ┌────────────────────────────┐
   ┌──────────────────────────────┐         │ data.tls_certificate        │
   │ kubernetes_details           │         │  .issuer (url = issuer_url) │
   │ @facets/kubernetes-details   │         │  → sha1_fingerprint         │
   │  oidc_issuer_url ────────────┼────┐    └──────────────┬─────────────┘
   └──────────────────────────────┘    │                   │ (thumbprint, if none supplied)
                                        │ issuer            ▼
   spec.issuer_url (override) ──────────┴───► ┌────────────────────────────┐
   spec.client_id_list (audiences) ─────────►│ aws_iam_openid_connect_     │
   spec.thumbprint_list ────────────────────►│   provider "gke"            │──► @facets/aws_iam_oidc_provider
   spec.tags ───────────────────────────────►│  url, client_id_list,       │    attributes: provider_arn,
                                              │  thumbprint_list, tags      │      issuer_url, client_id_list
                                              └────────────────────────────┘

   Result: a GKE service account token → AWS STS AssumeRoleWithWebIdentity → assume an AWS IAM role.
```

The issuer URL comes from `kubernetes_details.oidc_issuer_url` unless
`spec.issuer_url` overrides it. If no thumbprints are supplied, the module reads
the issuer's TLS certificate and uses its SHA1 fingerprint.

---

## Usage

```yaml
kind: aws_iam_oidc_provider
flavor: gke
version: "1.0"
disabled: true
spec:
  issuer_url: ""
  client_id_list:
    - sts.amazonaws.com
  thumbprint_list: []
  tags: {}
```

Leave `issuer_url` empty to use the issuer from the connected GKE cluster.

---

## Inputs

| Input | Type | Provider | Required | Description |
|-------|------|----------|----------|-------------|
| `cloud_account` | `@facets/aws_cloud_account` | aws | Yes | AWS account where the OIDC provider is created. |
| `kubernetes_details` | `@facets/kubernetes-details` | — | Yes | GKE cluster output providing `oidc_issuer_url`. |

---

## Spec

| Field | Type | Required | Default | Notes |
|-------|------|----------|---------|-------|
| `issuer_url` | string | No | `""` | Optional override. Empty → use `kubernetes_details.oidc_issuer_url`. Must be empty or start with `https://`. |
| `client_id_list` | array(string) | No | `["sts.amazonaws.com"]` | OIDC audiences allowed by AWS STS. |
| `thumbprint_list` | array(string) | No | `[]` | Optional SHA1 cert thumbprints (40 hex chars). Empty → derived from the issuer's TLS certificate. |
| `tags` | object | No | `{}` | Additional tags for the IAM OIDC provider. |

`issuer_url` is validated to be empty or start with `https://`.

---

## Outputs — `@facets/aws_iam_oidc_provider`

Attributes set in `outputs.tf`:

| Attribute | Description |
|-----------|-------------|
| `provider_arn` | ARN of the created AWS IAM OIDC provider. |
| `issuer_url` | The OIDC issuer URL registered in AWS IAM. |
| `client_id_list` | Audiences registered on the provider. |

No interfaces are emitted.

---

## Notes

- **Flat `kubernetes_details`.** This input is delivered as the attributes object
  itself (wired with `output_name: "attributes"`), so `oidc_issuer_url` is read
  at the top level — not under a nested `.attributes` key. Reading it nested
  yields `""` and fails downstream as an invalid URL.
- **Thumbprint derivation.** When `thumbprint_list` is empty, the module fetches
  the issuer's TLS certificate and uses `certificates[0].sha1_fingerprint`.
- **Tags.** User `spec.tags` are merged with `environment.cloud_tags`.
- **Disabled by default.** The sample sets `disabled: true` — enable the resource
  once the GKE issuer is reachable.
```
