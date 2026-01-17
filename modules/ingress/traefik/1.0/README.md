# Traefik Ingress Module (Nginx-Compatible Schema)

A Traefik ingress controller module for Facets platform with **Nginx-compatible schema**. This module provides a drop-in replacement for Nginx ingress while using Traefik as the underlying controller.

## Overview

- **Intent**: `ingress`
- **Flavor**: `traefik`
- **Version**: `1.0`
- **Platform**: AWS / Kubernetes
- **Schema**: Compatible with existing Nginx ingress configurations

## Key Features

### ✅ Nginx Schema Compatibility
- **domains** - Domain configurations with custom TLS certificates
- **rules** - Routing rules with domain_prefix + path combinations
- **session_affinity** - Sticky sessions with cookie configuration
- **cors** - Per-rule CORS settings
- **annotations** - Global and per-rule annotations
- **force_ssl_redirection** - Automatic HTTP to HTTPS redirect
- **custom_error_pages** - Custom 404/503 HTML pages
- **pdb** - Pod Disruption Budget configuration

### ✅ Security Features
- **Global Security Headers** - X-Frame-Options, CSP, Referrer-Policy, etc.
- **IP Whitelisting** - Protect monitoring endpoints (actuator, prometheus, metrics)
- **Basic Authentication** - Optional basic auth per ingress
- **Custom TLS Certificates** - Per-domain TLS with secret references

### ✅ Advanced Routing
- **Domain Prefixes** - Subdomain routing with wildcard support
- **Path-Based Routing** - Route different paths to different services
- **Header-Based Routing** - Route based on HTTP headers (exact or regex)
- **Path Rewriting** - Strip prefix before forwarding
- **Session Affinity** - Sticky sessions with configurable cookies
- **CORS** - Per-rule CORS with custom origins and methods

### ✅ Operational Features
- **Custom Error Pages** - Branded 404/503 error pages
- **Pod Disruption Budget** - High availability configuration
- **Resource Limits** - CPU and memory limits
- **Private Load Balancer** - Internal-only load balancer option
- **gRPC Support** - Enable gRPC protocol routing

## Module Files

- `facets.yaml` - Module definition with Nginx-compatible schema
- `variables.tf` - Terraform variable definitions
- `main.tf` - Traefik Helm deployment and routing implementation
- `outputs.tf` - Output attributes and interfaces
- `versions.tf` - Terraform version constraints
- `output-type-schema.json` - Output type schema

## Schema Structure

### Domains Configuration

```yaml
spec:
  domains:
    prod-wis-sg:
      domain: "workinsync.io"
      alias: "prod-wis-sg"
      custom_tls:
        enabled: true
        certificate: "${blueprint.self.secrets.WIS_SG_CERT}"
        private_key: "${blueprint.self.secrets.WIS_SG_KEY}"
```

### Rules Configuration

```yaml
spec:
  rules:
    stratus-authorization:
      disable: false
      domain_prefix: "*"  # Wildcard applies to all subdomains
      service_name: "${service.stratus-auth-blue.out.attributes.service_name}"
      namespace: "${service.stratus-auth-blue.out.attributes.namespace}"
      port: "8081"
      path: "/authorization"
      enable_rewrite_target: false
      enable_header_based_routing: false

      session_affinity:
        session_cookie_name: "stratus-blue"
        session_cookie_expires: 3600
        session_cookie_max_age: 3600

      cors:
        enable: false

      annotations:
        nginx.ingress.kubernetes.io/affinity-mode: "persistent"
```

### Global Security Headers

```yaml
spec:
  security_headers:
    x_frame_options: "SAMEORIGIN"
    content_security_policy: "frame-ancestors 'self' *.moveinsync.com *.workinsync.io"
    referrer_policy: "same-origin"
    x_content_type_options: "nosniff"
    x_xss_protection: "1; mode=block"
```

### IP Whitelisting for Monitoring Endpoints

```yaml
spec:
  ip_whitelist:
    enabled: true
    protected_paths:
      - "actuator"
      - "prometheus"
      - "/metrics"
    allowed_ips:
      - "10.0.0.0/8"
      - "10.101.0.0/16"
      - "172.31.0.0/16"
      - "54.251.0.116/32"
      # ... add all your whitelisted IPs
```

### Custom Error Pages

```yaml
spec:
  custom_error_pages:
    error-404:
      error_code: "404"
      page_content: |
        <!doctype html>
        <html>
          <body>
            <h1>Page Not Found</h1>
          </body>
        </html>

    error-503:
      error_code: "503"
      page_content: |
        <!doctype html>
        <html>
          <body>
            <h1>Service Unavailable</h1>
          </body>
        </html>
```

### Pod Disruption Budget

```yaml
spec:
  pdb:
    maxUnavailable: "1"
```

## Complete Example

```yaml
kind: ingress
flavor: traefik
version: "1.0"
disabled: false
metadata:
  name: main-ingress

depends_on:
  - kubernetes_cluster.my-cluster

spec:
  namespace: "traefik"
  service_type: LoadBalancer
  replicas: 2
  private: false
  basic_auth: false
  grpc: false
  force_ssl_redirection: true
  disable_base_domain: true

  # Global annotations
  global_annotations:
    service.beta.kubernetes.io/aws-load-balancer-ssl-negotiation-policy: "ELBSecurityPolicy-TLS13-1-2-2021-06"

  # Security headers (applied globally)
  security_headers:
    x_frame_options: "SAMEORIGIN"
    content_security_policy: "frame-ancestors 'self' *.moveinsync.com *.workinsync.io teams.microsoft.com"
    referrer_policy: "same-origin"
    x_content_type_options: "nosniff"
    x_xss_protection: "1; mode=block"

  # IP whitelist for monitoring endpoints
  ip_whitelist:
    enabled: true
    protected_paths:
      - "actuator"
      - "prometheus"
      - "/metrics"
    allowed_ips:
      - "10.0.0.0/8"
      - "10.101.0.0/16"
      - "172.31.0.0/16"

  # Domains
  domains:
    prod-wis-sg:
      domain: "workinsync.io"
      alias: "prod-wis-sg"
      custom_tls:
        enabled: true
        certificate: "${blueprint.self.secrets.WIS_SG_CERT}"
        private_key: "${blueprint.self.secrets.WIS_SG_KEY}"

  # Routing rules
  rules:
    # Authorization service with sticky sessions
    stratus-authorization:
      disable: false
      domain_prefix: "*"
      service_name: "${service.stratus-auth-blue.out.attributes.service_name}"
      namespace: "${service.stratus-auth-blue.out.attributes.namespace}"
      port: "8081"
      path: "/authorization"
      enable_rewrite_target: false

      session_affinity:
        session_cookie_name: "stratus-blue"
        session_cookie_expires: 3600
        session_cookie_max_age: 3600

      cors:
        enable: false

    # Onboarding service
    stratus-onboarding:
      disable: false
      domain_prefix: "*"
      service_name: "${service.stratus-self-onboarding.out.attributes.service_name}"
      namespace: "${service.stratus-self-onboarding.out.attributes.namespace}"
      port: "8081"
      path: "/onboarding"
      enable_rewrite_target: false

    # UI service (root path)
    default-stratus-ui:
      disable: false
      domain_prefix: "*"
      service_name: "${service.stratus-ui.out.attributes.service_name}"
      namespace: "${service.stratus-ui.out.attributes.namespace}"
      port: "80"
      path: "/"
      enable_rewrite_target: false

  # Custom error pages
  custom_error_pages:
    error-404:
      error_code: "404"
      page_content: "<!doctype html>..."

    error-503:
      error_code: "503"
      page_content: "<!doctype html>..."

  # Pod disruption budget
  pdb:
    maxUnavailable: "1"

  # Resource limits
  resources:
    requests:
      cpu: "200m"
      memory: "256Mi"
    limits:
      cpu: "1000m"
      memory: "1Gi"
```

## Migration from Nginx Ingress

### Direct Schema Compatibility

This module uses the **exact same schema** as your existing Nginx ingress, so migration is straightforward:

1. **Keep your existing spec** - No schema changes required
2. **Change flavor** - Update `flavor: nginx` to `flavor: traefik`
3. **Update version** - Set `version: "1.0"`
4. **Test** - Deploy and verify routing works

### Supported Nginx Features

| Nginx Feature | Traefik Equivalent | Supported |
|---------------|-------------------|-----------|
| `domains` | IngressRoute hosts | ✅ Yes |
| `rules` | IngressRoute routes | ✅ Yes |
| `domain_prefix` | Host matching | ✅ Yes (including wildcard `*`) |
| `session_affinity` | Sticky middleware | ✅ Yes |
| `cors` | Headers middleware | ✅ Yes |
| `enable_rewrite_target` | StripPrefix middleware | ✅ Yes |
| `force_ssl_redirection` | HTTPS redirect | ✅ Yes |
| `custom_error_pages` | Errors middleware + nginx pod | ✅ Yes |
| `annotations` (global) | Service annotations | ✅ Yes |
| `annotations` (per-rule) | IngressRoute annotations | ✅ Yes |
| `pdb` | PodDisruptionBudget | ✅ Yes |
| Global security headers | Headers middleware | ✅ Yes |
| IP whitelist (server-snippet) | IPWhiteList middleware | ✅ Yes |
| `basic_auth` | BasicAuth middleware | ✅ Yes |
| `grpc` | gRPC protocol | ✅ Yes |
| `enable_header_based_routing` | Header matchers | ✅ Yes |

### Annotation Mapping

Nginx annotations are handled differently:

| Nginx Annotation | Traefik Implementation |
|------------------|------------------------|
| `nginx.ingress.kubernetes.io/configuration-snippet` | Replaced by `security_headers` config |
| `nginx.ingress.kubernetes.io/server-snippet` | Replaced by `ip_whitelist` config |
| `nginx.ingress.kubernetes.io/affinity-mode` | Sticky sessions middleware (automatic) |
| `nginx.ingress.kubernetes.io/session-cookie-*` | Session affinity configuration |
| Service annotations | Passed through to Traefik service |

## Deployment

### 1. Create Output Type

```bash
raptor create output-type @outputs/ingress -f output-type-schema.json
```

### 2. Upload Module

```bash
# Validate
raptor create iac-module -f . --dry-run

# Upload
raptor create iac-module -f . --auto-create

# Publish
raptor publish iac-module ingress/traefik/1.0
```

### 3. Add to Project Type

```bash
raptor create resource-type-mapping <project-type> --resource-type ingress/traefik
```

### 4. Update Your Blueprint

Simply change the flavor:

```yaml
# Before (Nginx)
kind: ingress
flavor: nginx
version: "0.1"

# After (Traefik)
kind: ingress
flavor: traefik
version: "1.0"

# Everything else stays the same!
```

## Verification

### Check Traefik Pods

```bash
kubectl get pods -n traefik
kubectl logs -n traefik -l app.kubernetes.io/name=traefik
```

### Check IngressRoutes

```bash
kubectl get ingressroute -n traefik
kubectl describe ingressroute <name> -n traefik
```

### Check Middlewares

```bash
kubectl get middleware -n traefik
```

### Test Routing

```bash
# Get load balancer
LB=$(kubectl get svc -n traefik -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

# Test endpoint
curl -H "Host: workinsync.io" https://$LB/authorization
```

## Troubleshooting

### Issue: Routes not working

**Check:**
- IngressRoute created: `kubectl get ingressroute -n traefik`
- Service exists: `kubectl get svc <service-name>`
- Traefik logs: `kubectl logs -n traefik -l app.kubernetes.io/name=traefik`

### Issue: SSL redirect not working

**Check:**
- `force_ssl_redirection: true` in spec
- IngressRoute has `websecure` entrypoint
- Ports configured correctly in Helm values

### Issue: Sticky sessions not working

**Check:**
- `session_affinity` configured in rule
- Cookie middleware created: `kubectl get middleware -n traefik`
- Cookie present in response headers

### Issue: Custom error pages not showing

**Check:**
- Error pages ConfigMap: `kubectl get cm -n traefik`
- Error pages pod running: `kubectl get pods -n traefik | grep error`
- Errors middleware applied to routes

## Best Practices

1. **Use wildcard (`*`) for shared services** - Services used across all subdomains
2. **Use specific domain_prefix for tenant-specific services** - Isolate tenant traffic
3. **Enable sticky sessions for stateful apps** - Maintain session consistency
4. **Use custom error pages** - Better user experience
5. **Configure PDB** - Ensure high availability during deployments
6. **Set appropriate resource limits** - Based on your traffic volume
7. **Use IP whitelist for monitoring** - Protect sensitive endpoints

## Performance Considerations

- **Replicas**: Start with 2, scale based on traffic
- **Resources**: Adjust based on number of rules and traffic volume
- **PDB**: Set `maxUnavailable: 1` for smooth rolling updates
- **Load Balancer**: Use NLB for better performance on AWS

## Security Recommendations

1. **Always enable `force_ssl_redirection: true`**
2. **Configure security headers** globally
3. **Use IP whitelist** for actuator/prometheus/metrics
4. **Use custom TLS certificates** for production domains
5. **Enable basic auth** for sensitive ingresses if needed

## Support

For issues or questions:
- Check Traefik logs: `kubectl logs -n traefik -l app.kubernetes.io/name=traefik`
- Review IngressRoute: `kubectl describe ingressroute <name> -n traefik`
- Check middleware: `kubectl describe middleware <name> -n traefik`
