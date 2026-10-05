# nginx_gateway_fabric

Cloud-agnostic base module for [NGINX Gateway Fabric](https://github.com/nginxinc/nginx-gateway-fabric) (v2.4.1) using the Kubernetes Gateway API.

This module is designed to be called by cloud-specific flavor modules (AWS, GCP, Azure, OVH) that pass their own LB annotations and proxy configuration.

## Usage

```hcl
module "nginx_gateway_fabric" {
  source = "github.com/Facets-cloud/facets-utility-modules//nginx_gateway_fabric"

  instance      = var.instance
  instance_name = var.instance_name
  environment   = var.environment
  inputs        = var.inputs

  # Cloud-specific overrides
  service_annotations = {
    "service.beta.kubernetes.io/aws-load-balancer-type"            = "external"
    "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
  }

  nginx_proxy_extra_config = {
    rewriteClientIP = {
      mode = "ProxyProtocol"
      trustedAddresses = [{ type = "CIDR", value = "0.0.0.0/0" }]
    }
  }
}
```

## Variables

| Name | Type | Default | Required | Description |
|------|------|---------|----------|-------------|
| `instance` | `any` | — | yes | Facets instance object (must contain `spec`) |
| `instance_name` | `string` | — | yes | Architectural name of the ingress instance |
| `environment` | `any` | — | yes | Environment context (must contain `unique_name` and `namespace`) |
| `inputs` | `object` | — | yes | Module inputs (see `variables.tf` for full type) |
| `service_annotations` | `map(string)` | `{}` | no | Cloud-specific LB service annotations |
| `nginx_proxy_extra_config` | `any` | `{}` | no | Extra NginxProxy CRD config (e.g. proxy protocol) |

## Outputs

| Name | Description |
|------|-------------|
| `output_attributes` | Module output attributes (base_domain, gateway info, LB DNS) |
| `output_interfaces` | Route x domain cross-product interfaces (sensitive) |
| `domains` | List of all configured domain hostnames |
| `domain` | Base domain hostname (null if disabled) |
| `secure_endpoint` | HTTPS URL for the base domain (null if disabled) |
| `gateway_class` | GatewayClass name |
| `gateway_name` | Gateway resource name |
| `tls_secret` | TLS secret name for the base domain (null if disabled) |
| `load_balancer_hostname` | LB hostname (for CNAME records) |
| `load_balancer_ip` | LB IP address (for A records) |
| `lb_record_value` | DNS record value (hostname or IP) |
| `record_type` | DNS record type (CNAME or A) |
| `cloud_provider` | Detected cloud provider (AWS, GCP, AZURE) |
| `tenant_base_domain` | Tenant base domain from environment |
| `tenant_base_domain_id` | Route53 zone ID (empty if not AWS) |

## What this module creates

- NGINX Gateway Fabric Helm release (chart v2.4.1)
- GatewayClass and Gateway with per-domain HTTPS listeners
- HTTPRoute and GRPCRoute resources from spec rules
- Bootstrap TLS certificates (self-signed, replaced by cert-manager)
- cert-manager ClusterIssuer for HTTP-01 validation
- cert-manager Certificate resources (when mixed cert modes)
- Basic auth via NGF AuthenticationFilter CRD (optional)
- PodMonitor for Prometheus scraping (optional)
- ReferenceGrant for cross-namespace backends
- ClientSettingsPolicy for body size limits
- Route53 DNS records for base domain and wildcard (AWS only)
- HTTP to HTTPS redirect route (when force_ssl_redirection enabled)

## What flavor modules provide

| Config | Example (AWS) |
|--------|---------------|
| `service_annotations` | NLB scheme, target type, backend protocol, proxy protocol |
| `nginx_proxy_extra_config` | `rewriteClientIP.mode = "ProxyProtocol"` |
| ACM certificate handling | Detect ACM ARN, create ACK Certificate CRD, rewrite `certificate_reference` to K8s secret name before passing `instance` |
