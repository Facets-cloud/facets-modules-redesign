# DNS Zone — GCP (Cloud DNS Managed Zone)

Creates or manages **one Google Cloud DNS managed zone** and its record sets.
The zone can be **public** (internet-resolvable) or **private** (bound to one or
more VPC networks). It can either **create a new zone** or **attach records to
an existing zone** without owning it. Records are defined as a map in `spec`.

- **Cloud:** gcp
- **Resources created:** `google_dns_managed_zone` (conditional), `google_dns_record_set` (per record)
- **Output type:** `@facets/dns_zone`

---

## Architecture

```
   INPUTS                              THIS module                          OUTPUT
   ┌─────────────────────────┐         ┌────────────────────────────────┐   ┌────────────────────┐
   │ cloud_account           │         │ google_dns_managed_zone "this" │   │ @facets/dns_zone   │
   │  (@facets/gcp_cloud_    │────────►│   count = create_zone ? 1 : 0  │──►│ attributes:        │
   │   account, google prov) │         │   visibility: public | private │   │  zone_name         │
   │                         │         │   dnssec (public zones only)   │   │  dns_name          │
   │ network                 │         │   private_visibility_config →  │   │  name_servers      │
   │  (@facets/gcp-network-  │────────►│     network_self_links         │   │  (name_servers is  │
   │   details)              │         │                                │   │   [] for existing  │
   │  → project_id,          │         │ google_dns_record_set "this"   │   │   zones)           │
   │    vpc_self_link        │         │   for_each = spec.records      │   └────────────────────┘
   └─────────────────────────┘         │   name = <record>.<dns_name>   │
                                       └────────────────────────────────┘
```

- **Project** comes from `spec.project_id_override` if set, otherwise from the
  network input's `attributes.project_id`.
- **Private networks** come from `spec.network_self_links` if non-empty,
  otherwise default to the network input's `attributes.vpc_self_link`.
- If `spec.existing_zone_id` is set, the zone resource is **not** created;
  records attach to that existing zone instead.

---

## Usage

### Public zone

```yaml
kind: dns_zone
flavor: gcp
version: "1.1"
disabled: false
spec:
  zone_name: example-com
  dns_name: example.com.        # trailing dot; normalized if you omit it
  description: Public DNS zone
  project_id_override: ""
  existing_zone_id: ""
  visibility: public
  dnssec: "off"
  network_self_links: []
  records: {}
```

### Private zone with records

```yaml
kind: dns_zone
flavor: gcp
version: "1.1"
spec:
  zone_name: internal-example
  dns_name: internal.example.com.
  visibility: private
  network_self_links: []                 # empty -> binds the network input's VPC
  records:
    api:
      name: api                          # "" or "@" for the apex
      type: A
      ttl: 300
      values: ["10.0.0.10", "10.0.0.11"] # multi-value; or use `value` for one
    www:
      name: www
      type: CNAME
      value: api.internal.example.com    # trailing dot added automatically for CNAME
```

---

## Inputs

| Input | Type | Required | Purpose |
|-------|------|----------|---------|
| `cloud_account` | `@facets/gcp_cloud_account` | Yes | Provides the `google` provider (credentials + project). |
| `network` | `@facets/gcp-network-details` | Yes | Supplies `project_id` (default project) and `vpc_self_link` (default private-zone network). |

## Spec

| Field | Required | Default | Notes |
|-------|----------|---------|-------|
| `zone_name` | Yes | — | Managed-zone resource name, unique in the project. Pattern `^[a-z][a-z0-9-]{0,61}[a-z0-9]$`. |
| `dns_name` | Yes | — | Domain for the zone. Trailing dot required by Cloud DNS; the module adds it if missing. |
| `description` | No | `""` | Human-readable zone description. |
| `project_id_override` | No | `""` | Project to create the zone in. Empty = use the network input's project. |
| `existing_zone_id` | No | `""` | Attach records to this existing zone instead of creating one. Empty = create the zone. |
| `visibility` | No | `public` | `public` or `private`. |
| `dnssec` | No | `off` | `on` or `off`. Applied to **public** zones only (ignored for private). |
| `network_self_links` | No | `[]` | VPC network IDs/URLs for a private zone. Empty = bind the network input's VPC. |
| `records` | No | `{}` | Map of record key → `{ name, type, ttl, value, values }`. `type` ∈ A, AAAA, CNAME, TXT, NS, MX. Use `values` for multi-value sets, `value` for a single one. |

---

## Outputs — `@facets/dns_zone`

### Attributes (`outputs.tf`)

| Attribute | Description |
|-----------|-------------|
| `zone_name` | The managed zone name — the created zone's name, or `existing_zone_id` when attaching. |
| `dns_name` | The normalized DNS name (trailing dot). |
| `name_servers` | The zone's authoritative name servers when this module **creates** the zone; `[]` when attaching to an existing zone. |

No interfaces, no providers (this is a plain resource module).

---

## Notes

- **Creating the zone does not delegate the domain.** For a public zone,
  cutover still requires setting the registrar's NS records to the
  `name_servers` output. That is a migration step, not part of this module.
- **A zone with records cannot be deleted** until its records are removed.
- **DNSSEC only applies to public zones.** `main.tf` emits `dnssec_config`
  only when `visibility != private`.
- **Private zones need at least one network.** Google requires a network in
  `private_visibility_config`; the module falls back to the network input's
  `vpc_self_link` so a private zone works without setting
  `network_self_links`.
- **CNAME values are dot-terminated automatically.** In `locals.tf`, a CNAME
  `value`/`values` entry without a trailing dot gets one appended.
- **Existing-zone mode.** With `existing_zone_id` set, no
  `google_dns_managed_zone` is created and `name_servers` is empty — the module
  only manages the record sets.
