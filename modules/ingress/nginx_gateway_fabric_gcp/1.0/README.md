# NGINX Gateway Fabric (GCP)

Kubernetes Gateway API implementation for GCP GKE clusters.

## Overview

This module deploys **NGINX Gateway Fabric** on Google Kubernetes Engine (GKE). It is a thin cloud-specific wrapper around the base utility module, adding GCP Load Balancer annotations for internal load balancer support with global access.

### Cloud-Specific Behavior

| Setting | Behavior |
|---------|----------|
| **Load Balancer** | Google Cloud Load Balancer |
| **Private LB** | Sets `cloud.google.com/load-balancer-type: Internal`, `networking.gke.io/load-balancer-type: Internal`, `networking.gke.io/internal-load-balancer-allow-global-access: "true"` |
| **Public LB** | No annotations (default GCP external LB) |
| **Proxy Protocol** | Not used |
| **TLS Termination** | Always at the Gateway via cert-manager |

### Features

- **Gateway API Resources**: GatewayClass, Gateway, HTTPRoute, GRPCRoute
- **Advanced Routing**: Header matching, query parameter matching, HTTP method matching, RegularExpression path matching
- **URL Rewriting**: Path and hostname rewriting (ReplaceFullPath, ReplacePrefixMatch)
- **Traffic Management**: Canary deployments with weighted traffic splitting, request mirroring
- **Multi-Domain Support**: Routes work across all configured domains
- **TLS Management**: Automatic SSL certificates via cert-manager (HTTP-01) or custom TLS secrets
- **gRPC Support**: Native GRPCRoute resources with method-level matching
- **CORS**: Per-route Cross-Origin Resource Sharing configuration
- **Basic Authentication**: Native NGF AuthenticationFilter with per-route opt-out
- **Observability**: Prometheus metrics via PodMonitor
- **Security Headers**: Automatic HSTS, X-Frame-Options, X-Content-Type-Options, X-XSS-Protection
- **Cross-Namespace Backends**: ReferenceGrant support for services in other namespaces

---

## Configuration

### Basic Example

```json
{
  "kind": "ingress",
  "flavor": "nginx_gateway_fabric_gcp",
  "version": "1.0",
  "spec": {
    "private": false,
    "force_ssl_redirection": true,
    "rules": {
      "api": {
        "service_name": "api-service",
        "namespace": "default",
        "port": "8080",
        "path": "/api",
        "path_type": "PathPrefix"
      }
    }
  }
}
```

### Required Fields (per rule)

| Field | Description |
|-------|-------------|
| `service_name` | Kubernetes service name |
| `namespace` | Service namespace |
| `port` | Service port number |
| `path` | URL path (required for HTTP routes, not needed for gRPC) |

### Path Type Options

| Type | Default | Description |
|------|---------|-------------|
| `RegularExpression` | Yes | Matches paths using regex |
| `PathPrefix` | No | Matches paths starting with the specified prefix |
| `Exact` | No | Matches the exact path only |

---

## Routing Options

### Header-Based Routing

```json
{
  "rules": {
    "api_v2": {
      "service_name": "api-v2",
      "namespace": "default",
      "port": "8080",
      "path": "/",
      "path_type": "PathPrefix",
      "header_matches": {
        "version_header": {
          "name": "X-API-Version",
          "value": "v2",
          "type": "Exact"
        }
      }
    }
  }
}
```

### Query Parameter Matching

```json
{
  "rules": {
    "api_beta": {
      "service_name": "api-beta",
      "namespace": "default",
      "port": "8080",
      "path": "/api",
      "query_param_matches": {
        "version_param": {
          "name": "version",
          "value": "beta",
          "type": "Exact"
        }
      }
    }
  }
}
```

### HTTP Method Matching

```json
{
  "rules": {
    "api_readonly": {
      "service_name": "api-readonly",
      "namespace": "default",
      "port": "8080",
      "path": "/api",
      "method": "GET"
    }
  }
}
```

Options: `ALL` (default), `GET`, `POST`, `PUT`, `DELETE`, `PATCH`, `HEAD`, `OPTIONS`

---

## URL Rewriting

### Prefix Replacement

```json
{
  "url_rewrite": {
    "rewrite_rule": {
      "hostname": "internal-api.svc.cluster.local",
      "path_type": "ReplacePrefixMatch",
      "replace_path": "/new-api"
    }
  }
}
```

### Full Path Replacement

```json
{
  "url_rewrite": {
    "rewrite_rule": {
      "path_type": "ReplaceFullPath",
      "replace_path": "/v2/api"
    }
  }
}
```

---

## Header Modification

### Request Headers

```json
{
  "request_header_modifier": {
    "add": {
      "custom_header": { "name": "X-Custom-Header", "value": "custom-value" }
    },
    "set": {
      "source_header": { "name": "X-Request-Source", "value": "gateway" }
    },
    "remove": {
      "sensitive_header": { "name": "X-Sensitive-Header" }
    }
  }
}
```

### Response Headers

Security headers (HSTS, X-Frame-Options, X-Content-Type-Options, X-XSS-Protection) are automatically added to all responses.

```json
{
  "response_header_modifier": {
    "add": {
      "response_id": { "name": "X-Response-ID", "value": "unique-id" }
    },
    "set": {
      "cache_header": { "name": "Cache-Control", "value": "no-store" }
    },
    "remove": {
      "server_header": { "name": "Server" }
    }
  }
}
```

---

## Request Timeouts

```json
{
  "timeouts": {
    "request": "60s",
    "backend_request": "30s"
  }
}
```

Default: 300s for both request and backend_request.

---

## CORS Configuration

```json
{
  "cors": {
    "enabled": true,
    "allow_origins": {
      "origin1": { "origin": "https://example.com" }
    },
    "allow_methods": {
      "get": { "method": "GET" },
      "post": { "method": "POST" }
    },
    "allow_headers": {
      "content_type": { "header": "Content-Type" },
      "auth": { "header": "Authorization" }
    },
    "allow_credentials": true,
    "max_age": 86400
  }
}
```

---

## gRPC Support

### Route All gRPC Traffic

```json
{
  "rules": {
    "grpc_service": {
      "service_name": "grpc-backend",
      "namespace": "default",
      "port": "50051",
      "grpc_config": {
        "enabled": true,
        "match_all_methods": true
      }
    }
  }
}
```

### Specific Method Matching

```json
{
  "grpc_config": {
    "enabled": true,
    "match_all_methods": false,
    "method_match": {
      "get_user": {
        "service": "myapp.v1.UserService",
        "method": "GetUser",
        "type": "Exact"
      }
    }
  }
}
```

---

## Basic Authentication

Enable basic auth globally with per-route opt-out:

```json
{
  "spec": {
    "basic_auth": true,
    "rules": {
      "protected_api": {
        "service_name": "api",
        "port": "8080",
        "path": "/api",
        "namespace": "default"
      },
      "health_check": {
        "service_name": "api",
        "port": "8080",
        "path": "/health",
        "namespace": "default",
        "disable_auth": true
      }
    }
  }
}
```

Uses NGF's native `AuthenticationFilter` CRD. Credentials are auto-generated (`{instance_name}user` / random 10-char password).

---

## Canary Deployments

```json
{
  "canary_deployment": {
    "enabled": true,
    "canary_service": "api-v2",
    "canary_weight": 20
  }
}
```

Sends 20% of traffic to `api-v2` and 80% to primary service.

---

## Request Mirroring

```json
{
  "request_mirror": {
    "service_name": "api-shadow",
    "port": "8080",
    "namespace": "testing"
  }
}
```

---

## Multi-Domain Configuration

```json
{
  "spec": {
    "disable_base_domain": true,
    "domains": {
      "production": {
        "domain": "api.example.com",
        "alias": "prod"
      },
      "staging": {
        "domain": "staging-api.example.com",
        "alias": "staging",
        "certificate_reference": "staging-tls"
      }
    }
  }
}
```

All routes are accessible on all configured domains.

---

## TLS Certificate Management

### HTTP-01 Validation (Default)

- Creates bootstrap self-signed certificates for Gateway startup
- cert-manager replaces them with valid Let's Encrypt certificates via HTTP-01 challenge
- Requires port 80 accessible from internet
- Gateway-shim auto-manages certs when all domains use cert-manager

### Custom Certificates

Use an existing K8s TLS secret:

```json
{
  "domains": {
    "custom": {
      "domain": "api.example.com",
      "alias": "api",
      "certificate_reference": "my-existing-tls-secret"
    }
  }
}
```

---

## Private Load Balancer

```json
{
  "spec": {
    "private": true,
    "force_ssl_redirection": true
  }
}
```

Creates an internal GCP Load Balancer with global access enabled, allowing cross-region access to the internal LB.

**Annotations applied:**
- `cloud.google.com/load-balancer-type: Internal`
- `networking.gke.io/load-balancer-type: Internal`
- `networking.gke.io/internal-load-balancer-allow-global-access: "true"`

---

## Custom Helm Values

```json
{
  "spec": {
    "helm_values": {
      "nginx": {
        "config": {
          "logging": {
            "errorLevel": "debug"
          }
        }
      }
    }
  }
}
```

---

## Spec Options

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `private` | boolean | `false` | Use internal GCP Load Balancer with global access |
| `force_ssl_redirection` | boolean | `true` | Redirect HTTP to HTTPS |
| `disable_base_domain` | boolean | `false` | Disable auto-generated base domain |
| `domain_prefix_override` | string | - | Override auto-generated domain prefix |
| `basic_auth` | boolean | `false` | Enable basic authentication |
| `body_size` | string | `150m` | Maximum client request body size |
| `helm_wait` | boolean | `true` | Wait for Helm release to be ready |
| `helm_values` | object | - | Additional Helm values |

---

## Inputs

| Input | Type | Required | Description |
|-------|------|----------|-------------|
| `kubernetes_details` | `@facets/gke` | Yes | GKE cluster connection + providers |
| `kubernetes_node_pool_details` | `@facets/kubernetes_nodepool` | Yes | Node pool for scheduling |
| `cert_manager_details` | `@facets/cert_manager` | Yes | cert-manager for TLS certificates |
| `gateway_api_crd_details` | `@facets/gateway_api_crd` | Yes | Gateway API CRD installation |
| `artifactories` | `@facets/artifactories` | No | Container registry credentials |
| `prometheus_details` | `@facets/prometheus` | No | Prometheus for metrics collection |

---

## Outputs

| Output | Description |
|--------|-------------|
| `domains` | List of all configured domains |
| `domain` | Base domain (null if disabled) |
| `secure_endpoint` | HTTPS endpoint for base domain |
| `gateway_class` | GatewayClass name |
| `gateway_name` | Gateway resource name |
| `load_balancer_hostname` | LB hostname (for CNAME records) |
| `load_balancer_ip` | LB IP address (for A records) |
| `tls_secret` | TLS certificate secret name for base domain |
| `subdomain` | Subdomain mappings |

---

## Troubleshooting

### Check Gateway Status

```bash
kubectl get gateway -n <namespace>
kubectl describe gateway <gateway-name> -n <namespace>
```

### Check Routes

```bash
kubectl get httproute -n <namespace>
kubectl get grpcroute -n <namespace>
kubectl describe httproute <route-name> -n <namespace>
```

### Controller Logs

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=nginx-gateway-fabric -c nginx-gateway
```

### Data Plane Logs

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=nginx-gateway-fabric -c nginx
```

### Certificate Issues

```bash
kubectl get certificate -n <namespace>
kubectl describe certificate <cert-name> -n <namespace>
kubectl get clusterissuer
```

---

## Resources

- [NGINX Gateway Fabric Documentation](https://docs.nginx.com/nginx-gateway-fabric/)
- [Kubernetes Gateway API Specification](https://gateway-api.sigs.k8s.io/)
- [NGINX Gateway Fabric GitHub](https://github.com/nginxinc/nginx-gateway-fabric)
