# load_balancer / gcp

A **dual-mode global external/internal HTTP(S) L7 load balancer** for GCP. Fronts a backend
(typically a `vm-rs` service) with the full GCE L7 stack:

```
(global address) -> global forwarding rule -> target HTTP(S) proxy -> url map
   -> backend service -> unmanaged instance group -> backend VMs
   (+ optional :80 -> :443 redirect stack)
```

## Dual mode

| mode | how | result |
|------|-----|--------|
| **Greenfield** | leave `imports` empty; set `domains_json` | creates the IP + a `google_compute_managed_ssl_certificate` + the full stack |
| **Import / adopt** | set `imports.*` pins (live names, `ip_address`, `ssl_certificate_names`) | adopts an existing LB stack **0-change**; the IP + certs are referenced (never created/imported) |

Foundation (static IP, SSL certs) is **referenced as input** on import and **created** on greenfield,
selected by whether the corresponding `imports.*` pin is set.

## Inputs
- `cloud_account` (`@facets/gcp_cloud_account`)
- `network_details` (`@facets/gcp-network-details`)

## Key spec
`backend_service` (`@facets/service` picker — its VM self_links become the instance-group members) ·
`lb_scheme` (EXTERNAL_MANAGED / INTERNAL_MANAGED / EXTERNAL) · `backend_protocol`/`backend_port`/`timeout_sec` ·
`health_check` · `redirect_http` · `domains_json` / `routing_rules_json` (greenfield) · `imports` (adoption pins).
Output: `@custom/load_balancer`.

Extensive `ignore_changes` keep adoption 0-change against real-estate attributes (Cloud Armor, Cloud CDN,
ForceNew descriptions/ip_version, shared health-checks referenced not co-owned, multi named_port, etc.).
