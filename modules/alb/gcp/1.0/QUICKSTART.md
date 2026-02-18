# Quick Start Guide - GCP Ingress Module

## Step 1: Create Output Types

Before uploading the module, create the required output types:

```bash
# Navigate to output-types directory
cd ingress-gcp/output-types

# Create ingress output type
raptor create output-type @outputs/ingress -f ingress_output_type.json

# Create CloudRun service output type (if doesn't exist)
raptor create output-type @outputs/cloudrun_service -f cloudrun_service_output_type.json

# Create IP address output type
raptor create output-type @outputs/ip_address -f ip_address_output_type.json
```

**Note**: If `@facets/gcp_cloud_account` and `@facets/gcp_network` don't exist in your project type, you'll need to create those as well or modify the module to use existing types.

## Step 2: Upload Module

```bash
# Navigate back to module root
cd ..

# Validate module structure
raptor create iac-module -f . --dry-run

# Upload as PREVIEW for testing
raptor create iac-module -f . --auto-create

# Expected output:
# ✓ Module ingress/gcp/1.0 created successfully
# Status: PREVIEW
```

## Step 3: Add to Project Type

Make the module available in your project type:

```bash
# Replace with your actual project type name
PROJECT_TYPE="your-project-type"

# Add resource type mapping
raptor create resource-type-mapping $PROJECT_TYPE --resource-type ingress/gcp
```

## Step 4: Test the Module

Create a test blueprint with CloudRun services:

```yaml
# test-ingress.yaml
resources:
  # CloudRun API service
  - kind: service
    flavor: cloudrun
    version: "1.0"
    metadata:
      name: api
    spec:
      image: gcr.io/cloudrun/hello
      region: us-central1
      max_instances: 10

  # CloudRun web service
  - kind: service
    flavor: cloudrun
    version: "1.0"
    metadata:
      name: web
    spec:
      image: gcr.io/cloudrun/hello
      region: us-central1
      max_instances: 10

  # Ingress load balancer
  - kind: ingress
    flavor: gcp
    version: "1.0"
    metadata:
      name: main-lb
    inputs:
      gcp_cloud_account: ${cloud_account.main.out}
    spec:
      domains:
        example.com:
          default_service: "${service.web.out.attributes.service_name}"
          paths:
            /api:
              service: "${service.api.out.attributes.service_name}"
              path_type: PREFIX
          certificate:
            mode: auto

      global_config:
        timeout_sec: 60
        enable_cdn: false

      advanced:
        enable_http: true
        http_redirect: true
```

Apply the blueprint:

```bash
# Dry-run validation
raptor apply -f test-ingress.yaml -p test-project --dry-run

# Create a plan release
raptor create release -p test-project -e dev --plan -w

# If plan looks good, deploy
raptor create release -p test-project -e dev -w
```

## Step 5: Monitor Deployment

```bash
# Get releases
raptor get releases -p test-project -e dev

# View logs for the latest release
RELEASE_ID=$(raptor get releases -p test-project -e dev -o json | jq -r '.[0].id')
raptor logs release -p test-project -e dev -f $RELEASE_ID

# Check resource outputs after deployment
raptor get resource-outputs -p test-project -e dev ingress/main-lb
```

## Step 6: Configure DNS

1. Get the load balancer IP from outputs:
   ```bash
   raptor get resource-outputs -p test-project -e dev ingress/main-lb -o json | \
     jq -r '.attributes.lb_ip_address'
   ```

2. Create DNS A records:
   ```
   example.com     A    <LB_IP_ADDRESS>
   ```

3. Wait for:
   - DNS propagation: ~5-60 minutes
   - SSL certificate provisioning: ~15-30 minutes

4. Verify SSL certificate status:
   ```bash
   gcloud compute ssl-certificates list --global
   gcloud compute ssl-certificates describe <CERT_NAME> --global
   ```

## Step 7: Test the Load Balancer

```bash
# Test HTTP (should redirect to HTTPS)
curl -I http://example.com

# Test HTTPS
curl -I https://example.com

# Test path routing
curl https://example.com/api
```

## Step 8: Publish Module

Once testing is successful, publish the module:

```bash
raptor publish iac-module ingress/gcp/1.0

# Verify publication
raptor get iac-module ingress/gcp/1.0
```

## Common Issues

### Issue: "Output type not found"

**Solution**: Create the missing output types using the JSON schemas in `output-types/` directory.

```bash
raptor create output-type @outputs/<type-name> -f <schema-file>.json
```

### Issue: "Resource type not available in project type"

**Solution**: Add the resource type mapping:

```bash
raptor create resource-type-mapping <PROJECT_TYPE> --resource-type ingress/gcp
```

### Issue: "Certificate provisioning failed"

**Causes**:
- DNS not configured correctly
- Domain not publicly accessible
- Previous cert provisioning in progress

**Solution**:
1. Verify DNS A record points to LB IP
2. Wait 24 hours if previous provisioning failed
3. Check certificate status:
   ```bash
   gcloud compute ssl-certificates describe <CERT_NAME> --global
   ```

### Issue: "Backend service unhealthy"

**Causes**:
- CloudRun service not deployed
- IAM permissions missing
- Service in wrong region

**Solution**:
1. Verify CloudRun service is running:
   ```bash
   gcloud run services describe <SERVICE_NAME> --region=<REGION>
   ```

2. Grant Load Balancer invoker role:
   ```bash
   gcloud run services add-iam-policy-binding <SERVICE_NAME> \
     --region=<REGION> \
     --member=allUsers \
     --role=roles/run.invoker
   ```

## Example Configurations

### Simple Single Domain

```yaml
spec:
  domains:
    app.example.com:
      default_service: "${service.app.out.attributes.service_name}"
      certificate:
        mode: auto
```

### Multi-Domain with Custom Certificates

```yaml
spec:
  domains:
    api.example.com:
      default_service: "${service.api.out.attributes.service_name}"
      certificate:
        mode: managed
        managed_cert_name: api-cert

    www.example.com:
      default_service: "${service.web.out.attributes.service_name}"
      certificate:
        mode: existing
        existing_cert_name: existing-web-cert
```

### With CDN and Cloud Armor

```yaml
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

    security_policy: "my-cloud-armor-policy"

    custom_headers:
      X-Custom-Header: "my-value"
      X-Forwarded-Proto: "https"
```

### Complex Path Routing

```yaml
spec:
  domains:
    example.com:
      default_service: "${service.frontend.out.attributes.service_name}"
      paths:
        /api/v1:
          service: "${service.api-v1.out.attributes.service_name}"
          path_type: PREFIX
        /api/v2:
          service: "${service.api-v2.out.attributes.service_name}"
          path_type: PREFIX
        /admin:
          service: "${service.admin.out.attributes.service_name}"
          path_type: PREFIX
        /health:
          service: "${service.healthcheck.out.attributes.service_name}"
          path_type: EXACT
      certificate:
        mode: auto
```

## Next Steps

1. **Review module configuration** in the Facets UI
2. **Set up monitoring** for the load balancer and certificates
3. **Configure Cloud Armor** security policies if needed
4. **Enable CDN** for static content caching
5. **Set up IAP** for authentication on internal services
6. **Create environment-specific overrides** for production deployments

## Resources

- [Full README](README.md) - Comprehensive documentation
- [Output Type Schemas](output-types/) - JSON schemas for required types
- [Facets Module Writing Guide](https://docs.facets.cloud/modules/) - Official documentation
