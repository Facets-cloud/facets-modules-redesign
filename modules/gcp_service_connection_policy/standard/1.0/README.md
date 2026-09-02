# GCP Service Connection Policy

Provisions a **regional Google Cloud Network Connectivity Service Connection
Policy** that enables Private Service Connect (PSC) automation. Producer
services (for example Memorystore) use this policy to auto-allocate PSC
endpoints inside the consumer VPC's private subnet, up to a connection limit.

- **Cloud:** gcp
- **Resources created:** `google_network_connectivity_service_connection_policy`
- **Output type:** `@facets/gcp_service_connection_policy`

---

## Architecture

```
   INPUTS                                    RESOURCE (main.tf)                 OUTPUT
   ┌──────────────────────────────┐
   │ cloud_account                │
   │ @facets/gcp_cloud_account    │──project_id (fallback)─┐
   └──────────────────────────────┘                        │
                                                            ▼
   ┌──────────────────────────────┐          ┌──────────────────────────────────────┐
   │ network                      │          │ google_network_connectivity_          │
   │ @facets/gcp-network-details  │          │   service_connection_policy           │
   │  attributes.project_id       │─project─►│                                       │
   │  attributes.region           │─location►│  service_class = <spec.service_class> │──► @facets/gcp_service_connection_policy
   │  attributes.vpc_self_link    │─network─►│  network       = <vpc_self_link>      │    attributes: id, name, project_id,
   │  attributes.private_subnet_ids│─subnet─►│  psc_config {                         │      region, network, service_class,
   └──────────────────────────────┘          │    subnetworks = [private_subnet[0]]  │      connection_limit, subnetworks
                                              │    limit       = <connection_limit>   │
   spec.service_class ──────────────────────►│  }                                    │
   spec.connection_limit ───────────────────►│  labels = <merged labels>             │
   spec.description / labels ────────────────►└──────────────────────────────────────┘
```

`project_id` prefers `network.attributes.project_id` and falls back to
`cloud_account.attributes.project_id`. The policy name is derived from
`instance_name` + `environment.unique_name`, sanitized to lowercase
alphanumeric/`-` and truncated to 63 characters.

---

## Usage

```yaml
kind: gcp_service_connection_policy
flavor: standard
version: "1.0"
disabled: false
spec:
  service_class: gcp-memorystore
  connection_limit: 4
  description: Memorystore PSC service connection policy
  labels: {}
```

---

## Inputs

| Input | Type | Provider | Required | Description |
|-------|------|----------|----------|-------------|
| `cloud_account` | `@facets/gcp_cloud_account` | google | Yes | GCP account; provides fallback `project_id`. |
| `network` | `@facets/gcp-network-details` | — | Yes | VPC details: `project_id`, `region`, `vpc_self_link`, `private_subnet_ids`. |

---

## Spec

| Field | Type | Required | Default | Notes |
|-------|------|----------|---------|-------|
| `service_class` | string | Yes | `gcp-memorystore` | Producer service class. |
| `connection_limit` | integer | Yes | `4` | Maximum PSC connections allowed by this policy (minimum 1). |
| `description` | string | No | `Memorystore PSC service connection policy` | Free-text description. |
| `labels` | object | No | `{}` | Additional labels (merged with Facets-managed labels). |

`connection_limit` is validated to be a positive integer.

---

## Outputs — `@facets/gcp_service_connection_policy`

Attributes set in `outputs.tf`:

| Attribute | Description |
|-----------|-------------|
| `id` | Policy resource ID. |
| `name` | Sanitized policy name. |
| `project_id` | Project the policy lives in. |
| `region` | Region (policy location). |
| `network` | VPC self-link the policy targets. |
| `service_class` | The producer service class. |
| `connection_limit` | The configured connection limit. |
| `subnetworks` | List containing the first private subnet used for PSC allocation. |

No interfaces are emitted.

---

## Notes

- **Single subnet.** PSC endpoints are allocated only from the **first** entry
  in `network.attributes.private_subnet_ids`. If that list is empty, the
  subnetwork resolves to an empty string.
- **Regional.** The policy is created in `network.attributes.region`; it governs
  PSC automation for that region only.
- **Labels.** Facets adds `managed-by`, `instance-name`, `environment`, and
  `intent` labels on top of `environment.cloud_tags` and your `spec.labels`.
- **Name length.** The policy name is truncated to 63 characters after
  sanitization.
```
