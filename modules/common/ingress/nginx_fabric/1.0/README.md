# NGINX Gateway Fabric - Kubernetes Gateway API

Version: 1.0

## Overview

This module deploys the **NGINX Gateway Fabric** implementation of the Kubernetes Gateway API, providing advanced traffic management capabilities for ingress traffic.

**NGINX Gateway Fabric** is NGINX's implementation of the Kubernetes Gateway API specification, offering a modern, declarative approach to configuring ingress traffic with native support for advanced features like header-based routing, traffic splitting, and request/response transformation.

### Key Features

- **Kubernetes Gateway API**: Uses the standard Gateway API resources (GatewayClass, Gateway, HTTPRoute, GRPCRoute)
- **Advanced Routing**: Native support for header matching, URL rewriting, request mirroring
- **Multi-cloud Support**: AWS (NLB), Azure (LB), GCP (GCLB)
- **TLS Management**: Cert-manager integration for automatic SSL certificates
- **Rate Limiting**: Per-route rate limiting with burst control
- **IP Whitelisting**: Per-route IP access control
- **Canary Deployments**: Traffic splitting with percentage-based routing
- **gRPC Support**: Native GRPCRoute resources for gRPC services
- **WebSocket Support**: Automatic protocol upgrade handling
- **CORS**: Native CORS configuration via response headers
- **Authentication**: Basic auth and external authentication support
- **Observability**: Prometheus metrics and OpenTelemetry tracing

---

## Architecture

### Gateway API vs Ingress API

| Feature | Ingress API (nginx_k8s) | Gateway API (nginx_fabric) |
|---------|-------------------------|----------------------------|
| **Routing** | Annotation-based | Declarative API resources |
| **Header Matching** | Annotations | Native HTTPRoute spec |
| **URL Rewriting** | Annotations | URLRewrite filter |
| **Request Mirroring** | Not supported | RequestMirror filter |
| **Multi-tenancy** | Limited | Native Gateway separation |
| **Traffic Splitting** | Annotation-based canary | Native backendRefs weights |
| **gRPC** | Annotation-based | Native GRPCRoute resource |

### Resources Created

1. **Helm Release**: NGINX Gateway Fabric controller
2. **GatewayClass**: Defines the Gateway controller class
3. **Gateway**: Load balancer configuration with HTTP/HTTPS listeners
4. **HTTPRoute**: Traffic routing rules per service
5. **GRPCRoute**: gRPC-specific routing (when enabled)
6. **NginxProxy**: Global NGINX configuration
7. **ClientSettingsPolicy**: Rate limiting and IP whitelisting (per route)
8. **UpstreamSettingsPolicy**: Load balancing configuration (per route)
9. **TLS Secrets**: Custom SSL certificates
10. **Route53 Records**: DNS entries (AWS only)
11. **ServiceMonitor**: Prometheus metrics scraping

---

## Schema Simplification

This module uses meaningful naming conventions derived from nginx_k8s:

**Gateway naming:**
- `gateway_class_name`: Defaults to `{namespace}-{instance_name}` (same pattern as nginx_k8s ingress class)
- Can be overridden if needed

**Required fields per rule:**
- `service_name`: Kubernetes service name
- `port`: Service port number
- `path`: URL path (e.g., `/`, `/api`)
- `path_type`: Path matching type (`Exact`, `PathPrefix`, or `RegularExpression`)

**Optional fields with defaults:**
- `namespace`: Defaults to environment namespace

**Example - minimal configuration:**
```yaml
spec:
  private: false
  force_ssl_redirection: true
  rules:
    api:
      service_name: api-svc
      port: "8080"
      path: /
      path_type: PathPrefix
```

**Example - with custom gateway class:**
```yaml
spec:
  private: false
  force_ssl_redirection: true
  gateway_class_name: custom-nginx  # Override default
  rules:
    api:
      service_name: api-svc
      port: "8080"
      path: /api
      path_type: Exact
```

**Helm Chart Version:**
- By default, the module uses a bundled NGINX Gateway Fabric chart version 2.3.0
- You can override this by specifying `helm_chart_version` in spec
- When overridden, the module pulls the chart from the OCI registry

**Example - with custom chart version:**
```yaml
spec:
  private: false
  force_ssl_redirection: true
  helm_chart_version: "2.4.0"  # Override default 2.3.0
  rules:
    api:
      service_name: api-svc
      port: "8080"
      path: /
      path_type: PathPrefix
```

---

## Usage Examples

### Basic Configuration

```yaml
kind: ingress
flavor: nginx_fabric
version: '1.0'
spec:
  private: false
  force_ssl_redirection: true

  rules:
    api:
      service_name: api-service
      port: "8080"
      path: /api
      path_type: PathPrefix
```

### Advanced Routing with Header Matching

Header-based routing is a native Gateway API feature, no annotations required:

```yaml
spec:
  rules:
    api_v2:
      service_name: api-v2
      port: "8080"
      path: /
      path_type: PathPrefix
      header_matches:
      - name: X-API-Version
        value: v2
        type: Exact
      - name: User-Agent
        value: ".*Mobile.*"
        type: RegularExpression
```

### URL Rewriting

```yaml
spec:
  rules:
    legacy_api:
      service_name: new-api-service
      port: "8080"
      path: /old-api
      path_type: PathPrefix
      url_rewrite:
        path:
          type: ReplacePrefixMatch
          replacePrefixMatch: /new-api
```

### Canary Deployment with Traffic Splitting

```yaml
spec:
  rules:
    api:
      service_name: api-v1
      port: "8080"
      path: /
      path_type: PathPrefix
      canary_deployment:
        enabled: true
        canary_service: api-v2
        canary_weight: 20  # 20% traffic to v2, 80% to v1
```

### Rate Limiting

```yaml
spec:
  rules:
    public_api:
      service_name: api
      port: "8080"
      path: /
      path_type: PathPrefix
      rate_limiting:
        enabled: true
        requests_per_second: 50
        burst: 100
```

### IP Whitelisting

```yaml
spec:
  rules:
    admin:
      service_name: admin-api
      port: "8080"
      path: /admin
      path_type: PathPrefix
      ip_whitelist:
        enabled: true
        allowed_ips:
        - 10.0.0.0/8
        - 192.168.1.100
```

### CORS Configuration

```yaml
spec:
  rules:
    api:
      service_name: api
      port: "8080"
      path: /
      path_type: PathPrefix
      cors:
        enabled: true
        allow_origins:
        - https://example.com
        - https://app.example.com
        allow_methods:
        - GET
        - POST
        - PUT
        - DELETE
        allow_headers:
        - Content-Type
        - Authorization
        allow_credentials: true
        max_age: 86400
```

### Basic Authentication

Enable basic authentication for all routes. Credentials are automatically generated and available in module outputs.

```yaml
spec:
  basic_auth: true
  rules:
    api:
      service_name: api
      port: "8080"
      path: /
      path_type: PathPrefix
```

When `basic_auth: true` is set, the module will:
- Generate a random password
- Create a Kubernetes secret with username and password
- Expose credentials in outputs for use with external auth services

Access credentials via outputs:
- Username: `${module.nginx_fabric.username}`
- Password: `${module.nginx_fabric.password}` (sensitive)

### gRPC Support

```yaml
spec:
  rules:
    grpc_service:
      service_name: grpc-backend
      port: "50051"
      path: /
      path_type: PathPrefix
      grpc:
        enabled: true
        method_match:
        - service: myapp.v1.UserService
          method: GetUser
          type: Exact
```

### Custom TLS Certificates

```yaml
spec:
  domains:
    custom:
      domain: api.example.com
      alias: api
      custom_tls:
        enabled: true
        certificate: |
          -----BEGIN CERTIFICATE-----
          ...
          -----END CERTIFICATE-----
        private_key: |
          -----BEGIN PRIVATE KEY-----
          ...
          -----END PRIVATE KEY-----
```

### Request/Response Header Modification

```yaml
spec:
  rules:
    api:
      service_name: api
      port: "8080"
      request_header_modifier:
        add:
          X-Custom-Header: custom-value
        set:
          X-Request-Source: gateway
        remove:
        - X-Sensitive-Header
      response_header_modifier:
        add:
          X-Response-Time: "$request_time"
        set:
          X-Frame-Options: DENY
          Strict-Transport-Security: max-age=31536000
        remove:
        - Server
        - X-Powered-By
```

### Security Configuration

```yaml
spec:
  security:
    tls_version: TLSv1.3
    security_headers:
      hsts_enabled: true
      hsts_max_age: 31536000
      x_frame_options: DENY
      x_content_type_options: true
      x_xss_protection: true
```

### Observability Configuration

```yaml
spec:
  observability:
    metrics:
      enabled: true
      port: 9113
    tracing:
      enabled: true
      endpoint: http://jaeger-collector:14268/api/traces
      sampling_rate: 0.1
    logging:
      level: info
      format: json
```

---

## Feature Support Matrix

| # | Feature | Implementation | Status |
|---|---------|----------------|--------|
| 1 | Header-Based Routing | HTTPRoute.spec.rules.matches.headers | ✅ Native |
| 2 | Arbitrary Response Headers | ResponseHeaderModifier filter | ✅ Native |
| 3 | IP Whitelist per Path | ClientSettingsPolicy CRD | ✅ NGINX Policy |
| 4 | Canary Deployments | HTTPRoute traffic weights | ✅ Native |
| 5 | SSL/TLS Management | Gateway listeners + cert-manager | ✅ Native |
| 6 | Rate Limiting | ClientSettingsPolicy CRD | ✅ NGINX Policy |
| 7 | Authentication & Authorization | HTTPRoute + external auth | ✅ Native + Extension |
| 8 | Load Balancing Algorithms | UpstreamSettingsPolicy CRD | ✅ NGINX Policy |
| 9 | gRPC Support | GRPCRoute resource | ✅ Native |
| 10 | WebSocket Support | HTTPRoute (automatic) | ✅ Native |
| 11 | CORS Handling | ResponseHeaderModifier filter | ✅ Native |
| 12 | Request/Response Transformation | Header/URL modifiers | ✅ Native |
| 13 | Custom Error Pages | NginxProxy globalConfig | ✅ NGINX Config |
| 14 | Observability & Monitoring | Prometheus metrics + telemetry | ✅ Native |
| 15 | Multi-Cloud Support | Service annotations | ✅ Native |
| 16 | Configuration Management | NginxProxy CRD | ✅ NGINX Config |
| 17 | Security Features | Multiple CRDs + policies | ✅ Combined |

---

## Migration from nginx_k8s

### Key Differences

**1. Schema Changes:**
- `spec.rules` → `spec.rules`
- Annotation-based features → Native API fields
- `flavor: nginx_k8s` → `flavor: nginx_fabric`

**2. Feature Mapping:**

| nginx_k8s | nginx_fabric |
|-----------|--------------|
| `enable_header_based_routing` + annotations | `header_matches` array |
| `enable_rewrite_target` + `rewrite_target` | `url_rewrite` object |
| `more_set_headers` (annotation) | `response_header_modifier` |
| `cors.enable` (annotation) | `cors` (ResponseHeaderModifier) |
| `force_ssl_redirection` (annotation) | `force_ssl_redirection` (RequestRedirect filter) |

**3. Resource Types:**
- Ingress → HTTPRoute
- IngressClass → GatewayClass
- NGINX Ingress Controller → NGINX Gateway Fabric

### Migration Steps

1. **Install Gateway API CRDs** (if not already installed):
   ```bash
   kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml
   ```

2. **Deploy nginx_fabric module** alongside existing nginx_k8s:
   - Both can run simultaneously in the same cluster
   - Use different `instance_name` values

3. **Update route configurations**:
   - Change `spec.rules` to `spec.rules`
   - Convert annotation-based features to native API fields
   - Test routes individually

4. **Update DNS**:
   - Point DNS to new Gateway load balancer
   - Verify traffic routing

5. **Decommission nginx_k8s**:
   - Once nginx_fabric is stable, remove nginx_k8s module

---

## Requirements

- **Kubernetes**: 1.25+
- **Gateway API CRDs**: v1.4.1 (installed automatically)
- **Helm**: 3.x
- **Cert-manager**: v1.12+ (optional, for automatic SSL)
- **Prometheus Operator**: (optional, for ServiceMonitor)

---

## Cloud Provider Support

### AWS
- **Load Balancer**: Network Load Balancer (NLB)
- **DNS**: Route53 integration for automatic DNS records
- **Features**: Private load balancer, cross-zone load balancing

### Azure
- **Load Balancer**: Azure Load Balancer
- **Features**: Internal load balancer support

### GCP
- **Load Balancer**: Google Cloud Load Balancer
- **Features**: Internal load balancer with global access

---

## Outputs

- `domains`: List of all configured domains
- `nginx_fabric`: Resource metadata
- `domain`: Base domain (if not disabled)
- `secure_endpoint`: HTTPS endpoint for base domain
- `gateway_class`: GatewayClass name
- `gateway_name`: Gateway resource name
- `subdomain`: Subdomain mappings
- `tls_secret`: TLS certificate secret name
- `load_balancer_hostname`: LB hostname (CNAME)
- `load_balancer_ip`: LB IP address (A record)

---

## Migration Guide

### Upgrading from Previous Versions

**Field name changes:**
- `spec.routes` → `spec.rules` (for consistency with nginx_k8s)

**Naming convention changes:**
- `gateway_class_name`: Now defaults to `{namespace}-{instance_name}` (consistent with nginx_k8s ingress naming)

**Required fields (previously optional):**
- `path_type`: Now required per rule (was previously defaulted to "PathPrefix")
- `path`: Now required per rule (was previously defaulted to "/")

**Migration example:**

**Old configuration:**
```yaml
spec:
  routes:
    api:
      service_name: api-svc
      port: "8080"
```

**New configuration:**
```yaml
spec:
  rules:
    api:
      service_name: api-svc
      port: "8080"
      path: /
      path_type: PathPrefix
```

**Note:** Backward compatibility for `routes` has been removed. You must use `rules`.

---

## Troubleshooting

### Gateway not ready
```bash
kubectl get gateway -n <namespace>
kubectl describe gateway <gateway-name> -n <namespace>
```

### HTTPRoute not working
```bash
kubectl get httproute -n <namespace>
kubectl describe httproute <route-name> -n <namespace>
```

### Check NGINX Gateway Fabric logs
```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=nginx-gateway-fabric
```

### Verify GatewayClass
```bash
kubectl get gatewayclass
kubectl describe gatewayclass nginx
```

---

## Additional Resources

- [NGINX Gateway Fabric Documentation](https://docs.nginx.com/nginx-gateway-fabric/)
- [Kubernetes Gateway API Specification](https://gateway-api.sigs.k8s.io/)
- [Gateway API Getting Started Guide](https://gateway-api.sigs.k8s.io/guides/)
- [NGINX Gateway Fabric GitHub](https://github.com/nginxinc/nginx-gateway-fabric)

---

## Version History

- **1.0**: Initial release with full Gateway API support and 17 OSS features
