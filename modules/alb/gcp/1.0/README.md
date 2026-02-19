# ALB Module for GCP CloudRun

Creates a GCP Application Load Balancer with managed SSL certificates for routing traffic to CloudRun services. Uses a domain_prefix pattern similar to nginx/traefik ingress for subdomain routing.

## Features

- **Subdomain routing via domain_prefix**: Create subdomains like `api.example.com` using `domain_prefix: api`
- **Global and domain-specific rules**: Rules can apply to all domains or only specific ones
- **Path-based routing**: Route URL paths to different services (e.g., `/api` → api-service)
- **Managed SSL certificates**: Automatic SSL certificate provisioning per host
- **equivalent_prefixes**: Map prefixes to bare domain (e.g., `www` → bare domain)
- **Cloud CDN**: Optional CDN for caching static content
- **Identity-Aware Proxy (IAP)**: Optional authentication layer
- **Cloud Armor**: Security policy integration
- **HTTP to HTTPS redirect**: Automatic redirect from HTTP to HTTPS

## Domain Prefix Pattern

This module follows the same pattern as nginx/traefik ingress:

```
domains:
  main:
    domain: example.com  ← Base domain

rules:
  api:
    domain_prefix: api   ← Creates api.example.com
    service: api-service
```

### Rule Types

| Rule Type | Example | Description |
|-----------|---------|-------------|
| **Global rule** | `domain_prefix: api` (no domain_key) | Creates subdomain for ALL domains |
| **Domain-specific rule** | `domain_prefix: admin, domain_key: main` | Creates subdomain only for specified domain |
| **Bare domain rule** | `domain_prefix: "*"` | Routes to bare domain (example.com) |

## Architecture

```
Internet → Global Load Balancer (IP) → URL Map (host + path rules) → Backend Services → CloudRun
                ↓
           SSL Certificates (one per computed host)
```

**What gets created from configuration:**

```yaml
domains:
  main:
    domain: example.com

rules:
  default: { domain_prefix: "*", service: web }
  api: { domain_prefix: api, service: api }
  admin: { domain_prefix: admin, domain_key: main, service: admin }
```

Creates these hosts:
- `example.com` → web-service
- `api.example.com` → api-service
- `admin.example.com` → admin-service (domain-specific)

## Usage Examples

### Simple Single Domain with Subdomain

```yaml
kind: alb
flavor: gcp
version: "1.0"
spec:
  domains:
    main:
      domain: example.com
      certificate:
        mode: auto

  rules:
    # Bare domain (example.com) → frontend
    web:
      domain_prefix: "*"
      service: frontend-service
      path: "/"

    # api.example.com → API service
    api:
      domain_prefix: api
      service: api-service
      path: "/"
```

### Multi-Domain with Global and Domain-Specific Rules

```yaml
kind: alb
flavor: gcp
version: "1.0"
spec:
  domains:
    primary:
      domain: example.com
      equivalent_prefixes:
        - www  # www.example.com → example.com
      certificate:
        mode: auto

    secondary:
      domain: myapp.io
      certificate:
        mode: auto

  rules:
    # GLOBAL RULES - Apply to ALL domains

    # Bare domain routing
    default:
      domain_prefix: "*"
      service: web-service
      path: "/"

    # API subdomain for all domains
    # api.example.com + api.myapp.io
    api:
      domain_prefix: api
      service: api-service
      path: "/"

    # DOMAIN-SPECIFIC RULES

    # admin.example.com only (not admin.myapp.io)
    admin:
      domain_prefix: admin
      domain_key: primary  # Only for 'primary' domain
      service: admin-service
      path: "/"

    # blog.myapp.io only (not blog.example.com)
    blog:
      domain_prefix: blog
      domain_key: secondary  # Only for 'secondary' domain
      service: blog-service
      path: "/"
```

### With CDN, IAP, and Path Routing

```yaml
kind: alb
flavor: gcp
version: "1.0"
spec:
  domains:
    main:
      domain: app.example.com
      certificate:
        mode: auto

  rules:
    default:
      domain_prefix: "*"
      service: frontend-service
      path: "/"

    api:
      domain_prefix: api
      service: api-service
      path: "/"

    # Multiple paths on same subdomain
    api-v2:
      domain_prefix: api
      service: api-v2-service
      path: "/v2/*"
      path_type: PREFIX
      priority: 50  # Higher priority than api rule

  global_config:
    enable_cdn: true
    cdn_policy:
      cache_mode: CACHE_ALL_STATIC
      default_ttl: 3600

    enable_iap: true
    iap_config:
      oauth2_client_id: "${secrets.IAP_CLIENT_ID}"
      oauth2_client_secret: "${secrets.IAP_CLIENT_SECRET}"

    security_policy: "my-cloud-armor-policy"
    timeout_sec: 60

  advanced:
    enable_http: true
    http_redirect: true
    session_affinity: CLIENT_IP
```

## Configuration Reference

### Domain Options

| Field | Type | Description |
|-------|------|-------------|
| `domain` | string | Base domain name (e.g., example.com) |
| `equivalent_prefixes` | array | Prefixes that resolve to bare domain (e.g., ["www"]) |
| `certificate.mode` | string | `auto`, `managed`, `existing`, or `wildcard` |
| `certificate.managed_cert_name` | string | Custom cert name (mode=managed) |
| `certificate.existing_cert_name` | string | Existing cert name (mode=existing/wildcard) |

### Rule Options

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `domain_prefix` | string | `"*"` | Subdomain prefix. `"*"` or `""` = bare domain |
| `domain_key` | string | (empty) | If set, rule only applies to this domain |
| `service` | string | required | CloudRun service name |
| `path` | string | `"/"` | URL path for routing |
| `path_type` | string | `PREFIX` | `PREFIX` or `EXACT` |
| `priority` | integer | `100` | Lower = higher priority |

### Certificate Modes

| Mode | Description |
|------|-------------|
| `auto` | Auto-creates managed certificate from domain name |
| `managed` | Creates managed certificate with custom name |
| `existing` | References existing SSL certificate |
| `wildcard` | Uses wildcard certificate for all subdomains |

### Path Types

| Type | Behavior |
|------|----------|
| `PREFIX` | Matches path and all sub-paths (`/api` matches `/api`, `/api/v1`) |
| `EXACT` | Matches only exact path (`/api` matches only `/api`) |

## Module Structure

```
alb-gcp/
├── facets.yaml              # Module metadata and spec schema
├── variables.tf             # Terraform variable declarations
├── locals.tf                # Domain prefix computation and rule processing
├── ip_address.tf            # Global static IP address
├── certificates.tf          # SSL certificate management (per host)
├── backend_services.tf      # Backend services and serverless NEGs
├── url_map.tf               # URL map with computed host rules
├── target_proxies.tf        # HTTP/HTTPS target proxies
├── forwarding_rules.tf      # Global forwarding rules
├── outputs.tf               # Output attributes and interfaces
└── examples/                # Example configurations
```

## DNS Configuration

After deployment, configure DNS A records for each computed host:

```bash
# Get the load balancer IP
raptor get resource-outputs -p myproject -e prod alb/my-lb
```

Create DNS records:
```
example.com         A    <LB_IP_ADDRESS>
api.example.com     A    <LB_IP_ADDRESS>
admin.example.com   A    <LB_IP_ADDRESS>
```

**Note:** Managed SSL certificates require DNS to be configured before they can provision (15-30 minutes after DNS propagation).

## Troubleshooting

### Certificate Provisioning Fails

```bash
gcloud compute ssl-certificates describe <CERT_NAME> --global
```

Common issues:
- DNS not configured correctly
- Domain not publicly accessible
- Previous certificate provisioning in progress

### 404 Not Found

Check computed hosts and URL map:
```bash
gcloud compute url-maps describe <URL_MAP_NAME>
```

Common issues:
- Rule's domain_prefix not matching expected subdomain
- Service name incorrect
- Path matching (PREFIX vs EXACT) misconfigured

## Migration from Old Structure

**Old structure (explicit domains):**
```yaml
domains:
  api.example.com:
    default_service: api-service
```

**New structure (domain_prefix):**
```yaml
domains:
  main:
    domain: example.com

rules:
  api:
    domain_prefix: api
    service: api-service
```

Both create `api.example.com` → `api-service`, but the new structure:
- Allows global rules across multiple domains
- Supports domain-specific rules via `domain_key`
- Follows nginx/traefik ingress patterns
