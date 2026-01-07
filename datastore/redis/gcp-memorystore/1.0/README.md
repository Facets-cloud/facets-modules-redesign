# GCP Redis Memorystore Module

[![Terraform](https://img.shields.io/badge/terraform-1.5.7-blue.svg)](https://www.terraform.io/downloads.html)
[![GCP](https://img.shields.io/badge/gcp-memorystore-orange.svg)](https://cloud.google.com/memorystore)

## Overview

This module creates a managed Redis instance using Google Cloud Memorystore with high availability and security features. It provides enterprise-grade Redis with automatic TLS encryption, authentication, and high availability options.

The module integrates with existing VPC network infrastructure through private service access, ensuring secure and isolated connectivity. It supports both development (BASIC tier) and production (STANDARD_HA tier) workloads with configurable memory, Redis versions, and security settings.

## Environment as Dimension

**Environment-aware networking**: The module scales across environments by leveraging existing network infrastructure. Each environment uses its respective VPC network and private service connections, ensuring proper network isolation and security across development, staging, and production.

The instance naming includes the environment's unique identifier to prevent conflicts and enable proper resource tracking across multiple environments. Security configurations like TLS can be standardized across environments or customized per environment as needed.

## Resources Created

- **Redis Memorystore Instance**: Managed Redis with configurable memory (1-300GB) and service tier
- **Authentication Configuration**: Automatic secure auth token generation (always enabled)
- **TLS Encryption**: Configurable in-transit encryption with SERVER_AUTHENTICATION mode
- **High Availability Setup**: Read replicas and regional distribution for Standard HA tier
- **Network Integration**: Private network access via VPC private service connections
- **Certificate Management**: Automatic server CA certificate provisioning when TLS is enabled

## Security Considerations

This module implements security-first defaults designed for production workloads:

### Network Security
- **Private Network Access Only**: All instances use private IPs with VPC private service connections (required)
- **No Public Access**: Instances are only accessible from within the configured VPC network
- **Network Dependencies**: Requires a VPC network module with private service access connectivity

### Authentication & Encryption
- **Authentication Always Enabled**: Secure auth tokens are automatically generated and enforced
- **TLS Encryption (Default: Enabled)**: In-transit encryption using TLS 1.2+ with SERVER_AUTHENTICATION mode
  - **When TLS is Enabled**:
    - Port: **6378** (not the default 6379)
    - Protocol: TLS 1.2 or higher only
    - Mode: SERVER_AUTHENTICATION (client-to-server encryption with server authentication)
    - Server CA certificates automatically provisioned and rotated
    - Connection string uses `rediss://` scheme for automatic TLS client configuration
  - **When TLS is Disabled** (not recommended for production):
    - Port: 6379
    - No encryption
    - Connection string uses `redis://` scheme
- **Important**: TLS setting **cannot be changed** after instance creation without recreating the instance

### Certificate Management
When TLS is enabled:
- **Server CA certificates** are automatically generated and managed by GCP
- Certificates are valid for **10 years** from creation
- New certificates become available **5 years** after creation (5-year overlap for rotation)
- Server certificate rotation occurs every **180 days** (causes brief connection drop - implement retry logic)
- CA certificates are exposed in module outputs for client configuration
- Clients must download and install CA certificates from the `server_ca_certs` output

### Data Protection
- **Lifecycle Protection**: `prevent_destroy = true` configuration prevents accidental data loss
- **Backup Strategy**: Memorystore provides automatic backup capabilities through GCP infrastructure
- **Point-in-time Recovery**: Managed through Google Cloud Console or gcloud CLI

## TLS Performance Considerations

### Redis Version Impact
- **Redis 7.0+**: Significantly improved TLS performance
  - No connection drops during server certificate rotation
  - Better encryption/decryption performance
  - **Recommended for production** when using TLS
- **Redis 6.x and earlier**: May experience brief connection drops during certificate rotation

### Connection Limits with TLS
TLS encryption introduces connection limits based on instance size:

| Memory Tier | Redis 5.0/6.x | Redis 7.0+ |
|-------------|---------------|------------|
| M1 (1-4GB)  | 1,000         | 65,000     |
| M2 (5-10GB) | 2,500         | 65,000     |
| M3 (11-35GB)| 15,000        | 65,000     |
| M4 (36-100GB)| 30,000       | 65,000     |
| M5 (101+GB) | 65,000        | 65,000     |

**Monitor**: `redis.googleapis.com/clients/connected` metric to avoid exceeding limits.

### Performance Optimization
When using TLS:
- Reduce connection count by reusing long-running connections
- Consider M4 or larger instance sizes for better performance
- Increase client CPU resources (compute-optimized VMs recommended)
- Reduce payload sizes to minimize encryption overhead
- Use Redis 7.0+ for optimal performance

### Memory Impact
TLS reserves additional instance memory for encryption overhead. The `System Memory Usage Ratio` metric will be higher with TLS enabled compared to non-TLS instances.

## Configuration

### Redis Versions

Supported versions (as per [GCP Memorystore documentation](https://cloud.google.com/memorystore/docs/redis/supported-versions)):
- `REDIS_7_2` - Latest version
- `REDIS_7_0` - **Default** (recommended for TLS performance)
- `REDIS_6_X` - Stable version
- `REDIS_5_0` - Legacy support

### Service Tiers

- **BASIC**: Standalone instance for development/testing
  - Single node, no high availability
  - Suitable for non-critical workloads
- **STANDARD_HA**: Highly available primary/replica instances for production
  - Automatic failover
  - Read replicas enabled
  - Requires minimum 5GB memory

### Security Configuration

#### TLS Encryption Settings
- **enable_tls**: Boolean (default: `true`)
  - `true`: Enables SERVER_AUTHENTICATION mode with TLS 1.2+
    - Port changes to **6378**
    - Server CA certificates provided in outputs
    - Connection string uses `rediss://` scheme
  - `false`: No encryption (not recommended for production)
    - Uses standard port 6379
    - Connection string uses `redis://` scheme
  - **Cannot be changed after creation** - requires instance recreation

### Network Requirements

The network input module must provide:
- VPC self-link for authorized network configuration
- Private service access connection configured
- Region configuration matching the Redis instance region
- Valid private services connection details

## Client Configuration for TLS

When TLS is enabled (`enable_tls = true`), clients must be configured properly:

### Required Client Setup
1. **Download CA certificates**: From module outputs (`server_ca_certs` attribute)
2. **Configure TLS**: Point client to port **6378** (not 6379)
3. **Install certificates**: Place CA certificate file on client machine
4. **Use TLS-capable client**: Redis client library must support TLS (Redis 6.0+ for native support)

### Connection Example
```bash
# redis-cli with TLS (requires redis-cli 6.0+)
redis-cli -h <INSTANCE_IP> \
  -p 6378 \
  --tls \
  --cacert /path/to/server_ca.pem \
  -a <AUTH_TOKEN> \
  PING
```

### Alternative: Using Stunnel
For clients without native TLS support, use [Stunnel](https://www.stunnel.org/) as a TLS sidecar.

### Connection String Format
The module automatically provides connection strings:
- **With TLS**: `rediss://:AUTH_TOKEN@HOST:6378`
- **Without TLS**: `redis://:AUTH_TOKEN@HOST:6379`

## Module Outputs

### Attributes
- `instance_id`, `instance_name`: Instance identifiers
- `host`, `port`: Connection endpoint details (port is 6378 when TLS enabled)
- `redis_version`, `tier`, `memory_size_gb`: Instance configuration
- `transit_encryption_mode`: Current TLS mode (SERVER_AUTHENTICATION or DISABLED)
- `tls_enabled`: Boolean indicating TLS status
- `server_ca_certs`: CA certificates for TLS (sensitive, array of certificate objects)
- `auth_string`: Redis authentication token (sensitive)

### Interfaces
- `cluster.endpoint`: Full connection endpoint (host:port)
- `cluster.auth_token`: Authentication token (sensitive)
- `cluster.connection_string`: Ready-to-use connection string with correct scheme (sensitive)
- `cluster.tls_enabled`: TLS status flag
- `cluster.server_ca_certs`: CA certificates when TLS is enabled (sensitive)

## Best Practices

1. **Always enable TLS** for production workloads handling sensitive data
2. **Use Redis 7.0+** for better TLS performance and stability
3. **Monitor connection counts** when using TLS due to connection limits
4. **Implement retry logic** with exponential backoff for certificate rotation
5. **Use STANDARD_HA tier** for production to ensure high availability
6. **Configure private service access** before deploying the module
7. **Regularly rotate and update** CA certificates on client machines (10-year validity)
8. **Test TLS configuration** in development before deploying to production
9. **Use connection pooling** to reduce connection overhead with TLS
10. **Set appropriate memory size** accounting for TLS overhead

## Troubleshooting TLS

### Common Issues

**Connection Refused**:
- Verify port is 6378 (not 6379) when TLS is enabled
- Ensure client has TLS enabled
- Check CA certificate is properly installed

**Certificate Verification Failed**:
- Download latest CA certificates from module outputs
- Install CA on client machine
- Verify certificate file path in client configuration

**Connection Limit Exceeded**:
- Monitor `redis.googleapis.com/clients/connected` metric
- Scale up to larger memory tier
- Implement connection pooling
- Set `timeout` config to close idle connections

**Performance Degradation**:
- Upgrade to Redis 7.0 or higher
- Use M4 or larger instance size
- Increase client CPU resources
- Reduce payload sizes

## References

- [GCP Memorystore Documentation](https://cloud.google.com/memorystore/docs/redis)
- [About In-Transit Encryption](https://cloud.google.com/memorystore/docs/redis/about-in-transit-encryption)
- [Manage In-Transit Encryption](https://cloud.google.com/memorystore/docs/redis/manage-in-transit-encryption)
- [Supported Redis Versions](https://cloud.google.com/memorystore/docs/redis/supported-versions)
- [Memorystore Best Practices](https://cloud.google.com/memorystore/docs/redis/general-best-practices)
