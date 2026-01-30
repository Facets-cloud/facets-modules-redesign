# Traefik Ingress Module (Gateway API)

Traefik ingress controller using Kubernetes Gateway API with support for domains, rules, session affinity, CORS, custom error pages, IP whitelisting, and SSL redirection.

## Architecture Overview

```
                                    ┌─────────────────────────────────────────────────────┐
                                    │                   Kubernetes Cluster                 │
                                    │                                                      │
┌──────────┐    ┌─────────────┐    │  ┌─────────────┐    ┌─────────────┐    ┌──────────┐ │
│  Client  │───▶│  AWS NLB    │───▶│  │   Traefik   │───▶│ TraefikSvc  │───▶│   App    │ │
│ (Browser)│    │  (Port 443) │    │  │   (Pods)    │    │  (Routing)  │    │ (Service)│ │
└──────────┘    └─────────────┘    │  └─────────────┘    └─────────────┘    └──────────┘ │
                                    │        │                                            │
                                    │        ▼                                            │
                                    │  Reads: GatewayClass, Gateway, HTTPRoute,           │
                                    │         Middleware, TraefikService                  │
                                    └─────────────────────────────────────────────────────┘
```

## How It Works

### Components

| Resource | Purpose |
|----------|---------|
| **GatewayClass** | Registers Traefik as the Gateway controller |
| **Gateway** | Defines listeners (ports 8000/8443) and TLS configuration |
| **HTTPRoute** | Routing rules - matches host/path/headers to backend |
| **TraefikService** | Backend routing with sticky session support |
| **Middleware** | Request/response processing (headers, auth, CORS, etc.) |

### Traffic Flow

When a user hits a URL (e.g., `https://app.example.com/api`):

1. **DNS Resolution**: Browser resolves domain to AWS NLB IP (Route53 record created by module)

2. **NLB Receives Request**: AWS Network Load Balancer receives request on port 443 (HTTPS) or 80 (HTTP)

3. **Forward to Traefik**: NLB forwards to Traefik pods (port 8443 for HTTPS, 8000 for HTTP)

4. **TLS Termination**:
   - With cert-manager: Traefik terminates TLS using certificate from Kubernetes secret
   - With ACM: NLB terminates TLS, forwards plain HTTP to Traefik

5. **Traefik Processes Request**:
   - Checks Gateway for listener configuration
   - Finds matching HTTPRoute (by hostname, path, headers)
   - Applies Middlewares (headers, auth, CORS, etc.)
   - Forwards to TraefikService

6. **TraefikService Routes to Backend**: Forwards to your Kubernetes Service with optional sticky sessions

7. **Response Returns**: Response travels back through middlewares (headers added) to client

### Component Relationships

```
GatewayClass (mis-traefik)
       │
       │  "Traefik is the controller"
       ▼
Gateway (mis-traefik)
       │
       │  Listeners: port 8000 (HTTP), port 8443 (HTTPS + TLS)
       ▼
HTTPRoute (one per rule)
       │
       │  Matches: hostname + path + headers
       │  Filters: Middlewares
       ▼
TraefikService (one per rule)
       │
       │  Backend + sticky sessions
       ▼
Kubernetes Service (your app)
```

## Configuration

### Basic Example

```yaml
spec:
  namespace: default
  enable_crds: true                    # Install CRDs (true for first instance)
  gateway_api_version: v1.4.0
  replicas: 2
  service_type: LoadBalancer

  # TLS via cert-manager
  certificate:
    use_cert_manager: true
    issuer_name: letsencrypt-prod
    issuer_kind: ClusterIssuer

  # Domain configuration
  domains:
    my-domain:
      domain: example.com
      # Optional: ACM certificate for NLB TLS termination
      # acm_certificate_arn: arn:aws:acm:us-east-1:123456789:certificate/xxx

  # Routing rules
  rules:
    my-app:
      domain_prefix: app              # app.example.com
      path: /api
      service_name: my-service
      port: "8080"
```

### Spec Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `namespace` | string | `default` | Kubernetes namespace for Traefik |
| `create_namespace` | bool | `true` | Create namespace if it doesn't exist |
| `enable_crds` | bool | `true` | Install Traefik and Gateway API CRDs |
| `gateway_api_version` | string | `v1.4.0` | Gateway API version to install |
| `ingress_chart_version` | string | `38.0.2` | Traefik Helm chart version |
| `replicas` | number | `2` | Number of Traefik replicas |
| `service_type` | string | `LoadBalancer` | Service type (LoadBalancer, ClusterIP, NodePort) |
| `private` | bool | `false` | Use internal load balancer |
| `force_ssl_redirection` | bool | `true` | Redirect HTTP to HTTPS |
| `grpc` | bool | `false` | Enable gRPC support |
| `basic_auth` | bool | `false` | Enable basic authentication |
| `basic_auth_secret` | string | - | Secret name containing htpasswd data |

### Domain Configuration

```yaml
domains:
  my-domain:
    domain: example.com               # Base domain name
    alias: my-alias                   # Optional alias identifier
    acm_certificate_arn: arn:aws:...  # Optional ACM cert for NLB TLS
```

### Rule Configuration

```yaml
rules:
  my-rule:
    domain_prefix: app                # Subdomain (app.example.com) or * for wildcard
    path: /api                        # URL path prefix
    service_name: my-service          # Kubernetes service name
    port: "8080"                      # Service port
    namespace: default                # Service namespace (optional)
    disable: false                    # Disable this rule

    # Path rewriting
    enable_rewrite_target: false      # Strip path prefix before forwarding

    # Header-based routing (AND with path)
    enable_header_based_routing: true
    header_routing_rules:
      my-header:
        header_name: x-environment
        header_value: production
        match_type: exact             # exact or regex

    # Session affinity (sticky sessions)
    session_affinity:
      session_cookie_name: route
      session_cookie_expires: 3600
      session_cookie_max_age: 3600

    # CORS configuration
    cors:
      enable: true
      allowed_origins:
        - https://example.com
      allowed_methods:
        - GET
        - POST

    # Rule-specific response headers
    response_headers:
      x-app-version: "1.0.0"

    # Custom annotations
    annotations:
      custom-annotation: value
```

### Global Response Headers

Applied to all routes:

```yaml
global_response_headers:
  X-Frame-Options: SAMEORIGIN
  X-Content-Type-Options: nosniff
  Content-Security-Policy: "default-src 'self'"
  Referrer-Policy: same-origin
  X-XSS-Protection: "1; mode=block"
```

### Global Header Routing

Require specific headers for all routes:

```yaml
global_header_routing:
  enabled: true
  rules:
    provider-header:
      header_name: x-provider
      header_value: aws
      match_type: exact
```

### IP Whitelist

Protect specific paths by IP:

```yaml
ip_whitelist:
  enabled: true
  allowed_ips:
    - 10.0.0.0/8
    - 192.168.1.0/24
  protected_paths:
    - /actuator
    - /metrics
    - /prometheus
```

### Certificate Configuration (cert-manager)

```yaml
certificate:
  use_cert_manager: true
  issuer_name: letsencrypt-prod
  issuer_kind: ClusterIssuer          # or Issuer
```

### Resource Limits

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

### Pod Disruption Budget

```yaml
pdb:
  maxUnavailable: "1"
  # or
  minAvailable: "1"
```

## Multiple Instances

When deploying multiple Traefik instances in the same cluster:

```yaml
# First instance - install CRDs
spec:
  enable_crds: true
  namespace: traefik-public

# Second instance - skip CRDs (already installed)
spec:
  enable_crds: false
  namespace: traefik-internal
```

## Complete Example

```yaml
kind: ingress
flavor: traefik
version: "1.0"
disabled: false

inputs:
  kubernetes_cluster:
    resource_name: default
    resource_type: kubernetes_cluster

spec:
  namespace: default
  create_namespace: false
  enable_crds: true
  gateway_api_version: v1.4.0
  service_type: LoadBalancer
  replicas: 2
  private: false
  force_ssl_redirection: true

  # TLS via cert-manager
  certificate:
    use_cert_manager: true
    issuer_name: letsencrypt-prod
    issuer_kind: ClusterIssuer

  # Global response headers (security headers)
  global_response_headers:
    X-Frame-Options: SAMEORIGIN
    X-Content-Type-Options: nosniff
    Referrer-Policy: same-origin
    X-XSS-Protection: "1; mode=block"

  # Global header routing (require x-provider header)
  global_header_routing:
    enabled: true
    rules:
      provider:
        header_name: x-provider
        header_value: aws
        match_type: exact

  # IP whitelist for monitoring endpoints
  ip_whitelist:
    enabled: true
    allowed_ips:
      - 10.0.0.0/8
      - 172.16.0.0/12
    protected_paths:
      - /actuator
      - /metrics

  # Domains
  domains: {}

  # Routing rules
  rules:
    petclinic:
      domain_prefix: petclinic
      path: /
      service_name: petclinic
      port: "8080"
      namespace: default
      enable_header_based_routing: true
      header_routing_rules:
        env:
          header_name: x-environment
          header_value: dev
          match_type: exact
      session_affinity:
        session_cookie_name: route
        session_cookie_expires: 300
        session_cookie_max_age: 300

    test-deployment:
      domain_prefix: test
      path: /admin
      service_name: test-deployment
      port: "8080"
      namespace: default
      response_headers:
        x-app-version: "1.0.0"

  # Pod disruption budget
  pdb:
    maxUnavailable: "1"

  # Resource limits
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
```

## Inputs

| Input | Type | Required | Description |
|-------|------|----------|-------------|
| `kubernetes_cluster` | @outputs/kubernetes | Yes | Kubernetes cluster connection |

## Outputs

| Output | Description |
|--------|-------------|
| `namespace` | Namespace where Traefik is deployed |
| `service_name` | Traefik service name |
| `load_balancer_hostname` | NLB hostname |
| `helm_release_name` | Helm release name |

## Troubleshooting

### Check Gateway Status
```bash
kubectl get gateway -n <namespace>
kubectl describe gateway <name> -n <namespace>
```

### Check HTTPRoute Status
```bash
kubectl get httproute -n <namespace>
kubectl describe httproute <name> -n <namespace>
```

### Check Traefik Logs
```bash
kubectl logs -l app.kubernetes.io/name=traefik -n <namespace> --tail=100
```

### Check Certificate Status
```bash
kubectl get certificate -n <namespace>
kubectl describe certificate <name> -n <namespace>
```

### Check Middlewares
```bash
kubectl get middleware -n <namespace>
kubectl describe middleware <name> -n <namespace>
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| BackendTLSPolicy CRD missing | Gateway API version too old | Use v1.4.0+ |
| Certificate not ready | cert-manager issue | Check ClusterIssuer and cert-manager logs |
| 404 errors | HTTPRoute not matching | Verify hostname, path, and headers |
| SSL errors | Certificate secret missing | Check if cert-manager created the secret |
| CRD conflict on apply | CRDs from different helm release | Set `enable_crds: false` or uninstall old release |

## Module Files

| File | Description |
|------|-------------|
| `facets.yaml` | Module definition with schema |
| `variables.tf` | Terraform variable definitions |
| `main.tf` | Traefik Helm deployment, Gateway, HTTPRoutes |
| `crds.tf` | CRD installation (Traefik + Gateway API) |
| `outputs.tf` | Output attributes and interfaces |
| `versions.tf` | Terraform version constraints |
