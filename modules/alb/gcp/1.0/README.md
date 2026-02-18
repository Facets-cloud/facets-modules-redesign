# Ingress Module for GCP CloudRun

Creates a GCP Application Load Balancer with managed SSL certificates for routing traffic to CloudRun services.

## Features

- **Host-based routing**: Route different domains to different CloudRun services
- **Path-based routing**: Route URL paths to different services (e.g., `/api` → api-service, `/web` → web-service)
- **Managed SSL certificates**: Automatic SSL certificate provisioning via Google-managed certificates
- **Cloud CDN**: Optional CDN for caching static content
- **Identity-Aware Proxy (IAP)**: Optional authentication layer
- **Cloud Armor**: Security policy integration
- **HTTP to HTTPS redirect**: Automatic redirect from HTTP to HTTPS
- **Custom headers**: Add custom headers to backend requests
- **Session affinity**: Support for sticky sessions

## Architecture

```
Internet → Global Load Balancer (IP) → URL Map (routing rules) → Backend Services → CloudRun Services
                ↓
           SSL Certificates (Google-managed)
```

**Components Created:**
- Global static IP address
- Managed SSL certificates (one per domain)
- Backend services with serverless NEGs
- URL map with host and path rules
- HTTPS target proxy
- HTTP target proxy (optional, for redirect)
- Global forwarding rules (HTTPS + optional HTTP)

## Prerequisites

### Required Output Types

Before uploading this module, ensure these output types exist in your project type:

1. **`@facets/gcp_cloud_account`** - GCP provider configuration
   ```json
   {
     "properties": {
       "type": "object",
       "properties": {
         "attributes": {
           "type": "object",
           "properties": {
             "project_id": { "type": "string" },
             "region": { "type": "string" }
           }
         }
       }
     },
     "providers": [
       {
         "name": "google",
         "source": "hashicorp/google",
         "version": "5.0.0"
       }
     ]
   }
   ```

2. **`@outputs/cloudrun_service`** - CloudRun service outputs (for x-ui-output-type)
   ```json
   {
     "properties": {
       "type": "object",
       "properties": {
         "attributes": {
           "type": "object",
           "properties": {
             "service_name": { "type": "string" },
             "service_url": { "type": "string" }
           }
         }
       }
     },
     "providers": []
   }
   ```

3. **`@outputs/ingress`** - Ingress outputs (this module's default output)
   ```json
   {
     "properties": {
       "type": "object",
       "properties": {
         "attributes": {
           "type": "object",
           "properties": {
             "lb_name": { "type": "string" },
             "lb_ip_address": { "type": "string" },
             "lb_ip_name": { "type": "string" },
             "url_map_id": { "type": "string" },
             "domains": {
               "type": "array",
               "items": { "type": "string" }
             },
             "https_url": { "type": "string" }
           }
         },
         "interfaces": {
           "type": "object",
           "properties": {
             "https": {
               "type": "object",
               "properties": {
                 "host": { "type": "string" },
                 "port": { "type": "string" },
                 "protocol": { "type": "string" },
                 "url": { "type": "string" },
                 "ip_address": { "type": "string" }
               }
             }
           }
         }
       }
     },
     "providers": []
   }
   ```

4. **`@outputs/ip_address`** - IP address output (for nested output)
   ```json
   {
     "properties": {
       "type": "object",
       "properties": {
         "attributes": {
           "type": "object",
           "properties": {
             "ip_address": { "type": "string" }
           }
         }
       }
     },
     "providers": []
   }
   ```

5. **`@facets/gcp_network`** - Optional GCP network details
   ```json
   {
     "properties": {
       "type": "object",
       "properties": {
         "attributes": {
           "type": "object",
           "properties": {
             "network_name": { "type": "string" },
             "network_id": { "type": "string" },
             "subnetwork_name": { "type": "string" }
           }
         }
       }
     },
     "providers": []
   }
   ```

## Module Structure

```
ingress-gcp/
├── facets.yaml              # Module metadata and spec schema
├── variables.tf             # Terraform variable declarations
├── locals.tf                # Local variables and computed values
├── ip_address.tf            # Global static IP address
├── certificates.tf          # SSL certificate management
├── backend_services.tf      # Backend services and serverless NEGs
├── url_map.tf               # URL map with routing rules
├── target_proxies.tf        # HTTP/HTTPS target proxies
├── forwarding_rules.tf      # Global forwarding rules
├── outputs.tf               # Output attributes and interfaces
├── versions.tf              # Terraform version constraint
└── README.md                # This file
```

## Usage Example

### Simple Single Domain

```yaml
kind: ingress
flavor: gcp
version: "1.0"
metadata:
  name: api-lb
spec:
  domains:
    api.example.com:
      default_service: "${service.api.out.attributes.service_name}"
      certificate:
        mode: auto  # Auto-creates managed certificate
```

### Multi-Domain with Path Routing

```yaml
kind: ingress
flavor: gcp
version: "1.0"
metadata:
  name: multi-service-lb
spec:
  domains:
    example.com:
      default_service: "${service.frontend.out.attributes.service_name}"
      paths:
        /api:
          service: "${service.api.out.attributes.service_name}"
          path_type: PREFIX
        /admin:
          service: "${service.admin.out.attributes.service_name}"
          path_type: PREFIX
      certificate:
        mode: auto

    api.example.com:
      default_service: "${service.api.out.attributes.service_name}"
      certificate:
        mode: managed
        managed_cert_name: api-example-cert
```

### With CDN and IAP

```yaml
kind: ingress
flavor: gcp
version: "1.0"
metadata:
  name: secure-lb
spec:
  domains:
    app.example.com:
      default_service: "${service.app.out.attributes.service_name}"
      certificate:
        mode: auto

  global_config:
    enable_cdn: true
    cdn_policy:
      cache_mode: CACHE_ALL_STATIC
      default_ttl: 3600
      max_ttl: 86400

    enable_iap: true
    iap_config:
      oauth2_client_id: "${blueprint.self.secrets.IAP_CLIENT_ID}"
      oauth2_client_secret: "${blueprint.self.secrets.IAP_CLIENT_SECRET}"

    security_policy: "my-cloud-armor-policy"
    timeout_sec: 60

  advanced:
    enable_http: true
    http_redirect: true
    session_affinity: CLIENT_IP
```

### Manual Service Names

```yaml
kind: ingress
flavor: gcp
version: "1.0"
metadata:
  name: manual-lb
spec:
  domains:
    example.com:
      default_service: "my-cloudrun-service"  # Literal service name
      paths:
        /api:
          service: "api-service"  # Literal service name
      certificate:
        mode: existing
        existing_cert_name: "existing-ssl-cert"
```

## Configuration Reference

### Certificate Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| `auto` | Auto-creates managed certificate from domain name | Default, simplest option |
| `managed` | Creates managed certificate with custom name | When you need specific cert names |
| `existing` | References existing SSL certificate | When cert is managed elsewhere |

### Path Types

| Type | Behavior | Example |
|------|----------|---------|
| `PREFIX` | Matches path and all sub-paths | `/api` matches `/api`, `/api/v1`, `/api/users` |
| `EXACT` | Matches only exact path | `/api` matches only `/api` |

### CDN Cache Modes

| Mode | Description |
|------|-------------|
| `CACHE_ALL_STATIC` | Cache static content based on content type |
| `USE_ORIGIN_HEADERS` | Respect Cache-Control headers from CloudRun |
| `FORCE_CACHE_ALL` | Force cache all responses regardless of headers |

### Session Affinity Options

| Option | Description |
|--------|-------------|
| `NONE` | No session affinity (default) |
| `CLIENT_IP` | Route same client IP to same backend |
| `GENERATED_COOKIE` | Use generated cookie for affinity |

## Deployment Workflow

### 1. Create Output Types (if needed)

```bash
# Create CloudRun service output type
raptor create output-type @outputs/cloudrun_service -f cloudrun_service_schema.json

# Create ingress output type
raptor create output-type @outputs/ingress -f ingress_schema.json

# Create IP address output type
raptor create output-type @outputs/ip_address -f ip_address_schema.json
```

### 2. Upload Module

```bash
cd ingress-gcp

# Validate module structure
raptor create iac-module -f . --dry-run

# Upload as PREVIEW (for testing)
raptor create iac-module -f . --auto-create
```

### 3. Test in Preview Project

Create a test blueprint with CloudRun services and the ingress:

```yaml
# test-blueprint.yaml
resources:
  - kind: service
    flavor: cloudrun
    version: "1.0"
    metadata:
      name: api
    spec:
      image: gcr.io/my-project/api:latest
      region: us-central1

  - kind: service
    flavor: cloudrun
    version: "1.0"
    metadata:
      name: frontend
    spec:
      image: gcr.io/my-project/frontend:latest
      region: us-central1

  - kind: ingress
    flavor: gcp
    version: "1.0"
    metadata:
      name: lb
    spec:
      domains:
        example.com:
          default_service: "${service.frontend.out.attributes.service_name}"
          paths:
            /api:
              service: "${service.api.out.attributes.service_name}"
          certificate:
            mode: auto
```

Deploy and test:

```bash
# Apply blueprint
raptor apply -f test-blueprint.yaml -p test-project --dry-run

# Create release
raptor create release -p test-project -e dev --plan -w

# Check logs
raptor logs release -p test-project -e dev -f <RELEASE_ID>
```

### 4. Publish Module

```bash
raptor publish iac-module ingress/gcp/1.0
```

## DNS Configuration

After deployment, configure DNS records:

1. Get the load balancer IP:
   ```bash
   raptor get resource-outputs -p myproject -e prod ingress/lb
   ```

2. Create DNS A records pointing to the IP:
   ```
   example.com         A    <LB_IP_ADDRESS>
   api.example.com     A    <LB_IP_ADDRESS>
   ```

3. Wait for DNS propagation (typically 5-60 minutes)

4. Wait for managed SSL certificate provisioning (typically 15-30 minutes)

## Certificate Provisioning Notes

**Google-managed certificates require:**
1. DNS A record pointing to the load balancer IP
2. Domain must be publicly accessible
3. Provisioning time: 15-30 minutes after DNS propagation
4. Certificate status can be checked in GCP Console → Load Balancing → Certificates

**Certificate validation fails if:**
- DNS records are not configured correctly
- Domain is not publicly reachable
- Firewall rules block Google's validation servers

## Troubleshooting

### Certificate Provisioning Fails

Check certificate status:
```bash
gcloud compute ssl-certificates describe <CERT_NAME> --global
```

Common issues:
- DNS not configured correctly
- Domain not publicly accessible
- Previous certificate provisioning in progress (wait 24 hours)

### Backend Service Unhealthy

Check CloudRun service:
```bash
gcloud run services describe <SERVICE_NAME> --region=<REGION>
```

Common issues:
- CloudRun service not deployed
- Service in wrong region
- IAM permissions missing (Load Balancer needs Cloud Run Invoker role)

### 404 Not Found

Check URL map configuration:
```bash
gcloud compute url-maps describe <URL_MAP_NAME>
```

Common issues:
- Path matching incorrect (PREFIX vs EXACT)
- Service name reference incorrect
- Default service not configured

## Security Best Practices

1. **Always use HTTPS**: Enable `http_redirect: true` to redirect HTTP → HTTPS
2. **Enable IAP**: For internal applications, enable Identity-Aware Proxy
3. **Use Cloud Armor**: Add security policies for DDoS protection and WAF rules
4. **Restrict CloudRun ingress**: Set CloudRun services to `internal-and-cloud-load-balancing`
5. **Use custom headers**: Add `X-Forwarded-For` and authentication headers

## Cost Considerations

**Pricing components:**
- Global load balancer forwarding rules: ~$18/month per rule
- Managed SSL certificates: Free (up to 100 certificates)
- Backend service: ~$0.008 per GB of egress
- Cloud CDN (if enabled): ~$0.08 per GB
- Cloud Armor (if enabled): ~$5/month base + per-rule fees

**Cost optimization:**
- Use fewer forwarding rules (combine domains with host-based routing)
- Enable CDN to reduce origin traffic
- Use path-based routing to minimize backend services

## Limitations

1. **CloudRun regions**: Backend services must be in the same region as CloudRun services (configure in cloud_account input)
2. **Certificate limit**: 100 managed certificates per project
3. **Domain verification**: Domains must be publicly accessible for certificate provisioning
4. **Path matching**: GCP URL maps support up to 100 path rules per path matcher
5. **Timeout**: Maximum backend timeout is 3600 seconds (1 hour)

## References

- [GCP Load Balancing Documentation](https://cloud.google.com/load-balancing/docs)
- [CloudRun Load Balancer Integration](https://cloud.google.com/run/docs/mapping-custom-domains)
- [Managed SSL Certificates](https://cloud.google.com/load-balancing/docs/ssl-certificates/google-managed-certs)
- [Cloud CDN Documentation](https://cloud.google.com/cdn/docs)
- [Cloud Armor Documentation](https://cloud.google.com/armor/docs)
