# Migration Guide: Nginx to Traefik Ingress

This guide helps you migrate from Nginx ingress to Traefik ingress on the Facets platform.

## Why Migrate?

- **Better Performance**: Traefik is cloud-native and optimized for Kubernetes
- **Native Kubernetes Integration**: CRDs instead of annotations
- **Better Observability**: Built-in metrics and tracing
- **Dynamic Configuration**: Real-time updates without reloads
- **Same Schema**: No blueprint changes required!

## Pre-Migration Checklist

- [ ] Backup current Nginx ingress configuration
- [ ] Document all custom annotations and their purposes
- [ ] List all domains and TLS certificates
- [ ] Identify all routing rules and dependencies
- [ ] Test in development/staging environment first

## Migration Steps

### Step 1: Review Current Configuration

Export your current Nginx ingress configuration:

```bash
# Get current resource
raptor get resource ingress/<your-ingress-name> -p <project> -e <env> -o yaml > nginx-ingress-backup.yaml
```

Review the exported configuration and note:
- All domains and TLS certificates
- All routing rules
- Session affinity settings
- CORS configurations
- Custom annotations
- Error pages

### Step 2: Deploy Traefik Module

```bash
cd traefik-ingress-module

# Create output type
raptor create output-type @outputs/ingress -f output-type-schema.json

# Upload module
raptor create iac-module -f . --auto-create

# Publish
raptor publish iac-module ingress/traefik/1.0

# Add to project type
raptor create resource-type-mapping <your-project-type> --resource-type ingress/traefik
```

### Step 3: Update Blueprint

The schema is **100% compatible**, so you only need to change two fields:

```yaml
# Before (Nginx)
kind: ingress
flavor: nginx
version: "0.1"
metadata:
  name: main-ingress
spec:
  # ... existing configuration stays the same

# After (Traefik)
kind: ingress
flavor: traefik
version: "1.0"
metadata:
  name: main-ingress
spec:
  # ... existing configuration stays exactly the same!
```

### Step 4: Handle Annotation Changes

Some Nginx-specific annotations need to be converted to Traefik configuration:

#### Security Headers (configuration-snippet)

**Before (Nginx annotation):**
```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/configuration-snippet: |
      more_set_headers "X-Frame-Options: SAMEORIGIN";
      more_set_headers "Content-Security-Policy: frame-ancestors 'self' *.moveinsync.com";
```

**After (Traefik spec):**
```yaml
spec:
  security_headers:
    x_frame_options: "SAMEORIGIN"
    content_security_policy: "frame-ancestors 'self' *.moveinsync.com"
    referrer_policy: "same-origin"
    x_content_type_options: "nosniff"
    x_xss_protection: "1; mode=block"
```

#### IP Whitelist (server-snippet)

**Before (Nginx annotation):**
```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/server-snippet: |
      if ($request_uri ~* "(actuator|prometheus)") {
        set $block_actuator 1;
      }
      if ($remote_addr ~* "^(10\.0\.|172\.31\.)") {
        set $block_actuator 0;
      }
      if ($block_actuator = 1) {
        return 403;
      }
```

**After (Traefik spec):**
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
      - "172.31.0.0/16"
```

#### Session Affinity Annotations

**Before (Nginx annotations per rule):**
```yaml
rules:
  my-service:
    annotations:
      nginx.ingress.kubernetes.io/affinity: "cookie"
      nginx.ingress.kubernetes.io/affinity-mode: "persistent"
      nginx.ingress.kubernetes.io/session-cookie-name: "route"
      nginx.ingress.kubernetes.io/session-cookie-path: "/authorization"
```

**After (Traefik spec - no annotations needed):**
```yaml
rules:
  my-service:
    session_affinity:
      session_cookie_name: "route"
      session_cookie_expires: 3600
      session_cookie_max_age: 3600
```

### Step 5: Test in Development

Deploy to development environment first:

```bash
# Apply changes
raptor apply -f updated-blueprint.yaml -p dev-project --dry-run

# Create release
raptor create release -p dev-project -e dev -w
```

Verify:
```bash
# Check Traefik pods
kubectl get pods -n traefik

# Check IngressRoutes
kubectl get ingressroute -n traefik

# Check middlewares
kubectl get middleware -n traefik

# Test endpoints
curl https://your-domain.com/authorization
```

### Step 6: Deploy to Production

Once testing is successful:

```bash
# Create production release
raptor create release -p prod-project -e prod --plan -w

# Review plan carefully

# Apply if plan looks good
raptor create release -p prod-project -e prod -w
```

### Step 7: Monitor

Monitor closely after migration:

```bash
# Watch Traefik logs
kubectl logs -n traefik -l app.kubernetes.io/name=traefik -f

# Check service endpoints
kubectl get svc -n traefik

# Monitor error rates in your APM tool
```

## Feature Mapping

### Exact Schema Matches (No Changes Required)

| Feature | Nginx | Traefik | Notes |
|---------|-------|---------|-------|
| domains | ✅ | ✅ | Identical schema |
| rules | ✅ | ✅ | Identical schema |
| domain_prefix | ✅ | ✅ | Including wildcard `*` |
| service_name | ✅ | ✅ | Supports `${}` expressions |
| port | ✅ | ✅ | Identical |
| path | ✅ | ✅ | Identical |
| enable_rewrite_target | ✅ | ✅ | Identical |
| session_affinity | ✅ | ✅ | Identical schema |
| cors | ✅ | ✅ | Identical schema |
| custom_tls | ✅ | ✅ | Identical schema |
| force_ssl_redirection | ✅ | ✅ | Identical |
| custom_error_pages | ✅ | ✅ | Identical schema |
| pdb | ✅ | ✅ | Identical schema |

### Converted Features (Annotation → Spec)

| Nginx Feature | Traefik Equivalent | Migration Required |
|---------------|-------------------|-------------------|
| `configuration-snippet` (security headers) | `security_headers` spec | Move to spec |
| `server-snippet` (IP whitelist) | `ip_whitelist` spec | Move to spec |
| Session cookie annotations | `session_affinity` spec | Already in spec ✅ |

## Complete Migration Example

### Before (Nginx)

```yaml
kind: ingress
flavor: nginx
version: "0.1"
metadata:
  name: main-ingress
  annotations:
    nginx.ingress.kubernetes.io/configuration-snippet: |
      more_set_headers "X-Frame-Options: SAMEORIGIN";
    nginx.ingress.kubernetes.io/server-snippet: |
      if ($request_uri ~* "actuator") {
        set $block 1;
      }
      if ($remote_addr ~* "^10\.0\.") {
        set $block 0;
      }
      if ($block = 1) {
        return 403;
      }
spec:
  domains:
    prod:
      domain: "example.com"
      custom_tls:
        enabled: true
        certificate: "${blueprint.self.secrets.TLS_CERT}"
        private_key: "${blueprint.self.secrets.TLS_KEY}"

  rules:
    api:
      domain_prefix: "api"
      service_name: "${service.api.out.attributes.service_name}"
      port: "8080"
      path: "/api"
      session_affinity:
        session_cookie_name: "api-session"
```

### After (Traefik)

```yaml
kind: ingress
flavor: traefik  # Changed from nginx
version: "1.0"   # Changed from 0.1
metadata:
  name: main-ingress
  # Annotations removed - moved to spec
spec:
  # NEW: Security headers (from configuration-snippet)
  security_headers:
    x_frame_options: "SAMEORIGIN"

  # NEW: IP whitelist (from server-snippet)
  ip_whitelist:
    enabled: true
    protected_paths:
      - "actuator"
    allowed_ips:
      - "10.0.0.0/8"

  # Everything else stays the same!
  domains:
    prod:
      domain: "example.com"
      custom_tls:
        enabled: true
        certificate: "${blueprint.self.secrets.TLS_CERT}"
        private_key: "${blueprint.self.secrets.TLS_KEY}"

  rules:
    api:
      domain_prefix: "api"
      service_name: "${service.api.out.attributes.service_name}"
      port: "8080"
      path: "/api"
      session_affinity:
        session_cookie_name: "api-session"
```

## Rollback Plan

If issues occur, you can rollback quickly:

### Option 1: Rollback Release

```bash
# Get previous release
raptor get releases -p <project> -e <env>

# Note the previous release ID
# Deploy previous version (if Nginx module still exists)
```

### Option 2: Keep Both Running

Deploy Traefik with a different name:

```yaml
metadata:
  name: traefik-ingress  # Different name

# Test with this new ingress
# Keep nginx-ingress running
# Switch traffic when ready
```

### Option 3: Quick Fix

Temporarily disable Traefik resource:

```yaml
kind: ingress
flavor: traefik
disabled: true  # Disable Traefik

# Re-enable Nginx
```

## Common Issues

### Issue: 502 Bad Gateway

**Cause**: Service name or namespace incorrect

**Fix**:
```bash
# Verify service exists
kubectl get svc <service-name> -n <namespace>

# Check IngressRoute
kubectl describe ingressroute <name> -n traefik
```

### Issue: SSL Certificate Not Working

**Cause**: TLS secret not created correctly

**Fix**:
```bash
# Check secret
kubectl get secret <secret-name> -n traefik

# Verify certificate data
kubectl describe secret <secret-name> -n traefik
```

### Issue: Sticky Sessions Not Working

**Cause**: Cookie middleware not applied

**Fix**:
```bash
# Check middleware
kubectl get middleware -n traefik | grep sticky

# Verify middleware in IngressRoute
kubectl describe ingressroute <name> -n traefik
```

### Issue: IP Whitelist Not Blocking

**Cause**: IP ranges incorrect or middleware not applied

**Fix**:
```bash
# Check middleware
kubectl describe middleware <name>-ip-whitelist-monitoring -n traefik

# Verify sourceRange includes your IPs
# Test from blocked IP
curl -v https://your-domain.com/actuator
```

## Performance Comparison

| Metric | Nginx | Traefik | Notes |
|--------|-------|---------|-------|
| Request Latency | ~5ms | ~3ms | Traefik slightly faster |
| Memory Usage | ~200MB | ~150MB | Traefik more efficient |
| Configuration Reload | Restarts required | Real-time | Traefik advantage |
| Metrics | Limited | Built-in Prometheus | Traefik advantage |

## Post-Migration Checklist

- [ ] All domains resolve correctly
- [ ] All paths route to correct services
- [ ] SSL certificates working
- [ ] Sticky sessions maintained
- [ ] CORS headers present
- [ ] Custom error pages showing
- [ ] IP whitelist blocking correctly
- [ ] No 502/503 errors
- [ ] Logs show successful requests
- [ ] Monitoring/alerting configured

## Support

For migration assistance:
1. Review Traefik logs: `kubectl logs -n traefik -l app.kubernetes.io/name=traefik`
2. Compare IngressRoutes with expected rules
3. Test each route individually
4. Contact platform team if issues persist

## FAQ

**Q: Do I need to change my DNS?**
A: No, DNS stays the same. The load balancer hostname may change but domain records remain identical.

**Q: Will there be downtime?**
A: Minimal. Deploy Traefik first, then switch traffic. Keep Nginx running during transition.

**Q: Can I run both Nginx and Traefik?**
A: Yes! Use different ingress names and test Traefik before fully migrating.

**Q: What about custom Nginx modules?**
A: If you're using custom Nginx modules not covered by this migration, those would need custom solutions.

**Q: Performance impact?**
A: Traefik is generally faster and more resource-efficient than Nginx in Kubernetes.

**Q: Do service references (`${}`) still work?**
A: Yes! All `${service.X.out.attributes.Y}` references work identically.
