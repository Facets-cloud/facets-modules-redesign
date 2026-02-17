# AWS S3 Bucket - Standard Flavor

AWS S3 bucket module with support for creating new buckets or importing/managing existing ones.

## Features

- **Dual Mode**: Create new buckets OR import existing buckets into Facets management
- **Encryption**: Server-side encryption with SSE-S3 (default) or SSE-KMS
- **Versioning**: Optional bucket versioning support
- **Public Access Blocking**: All public access blocked by default (AWS best practice)
- **Lifecycle Rules**: Configure transitions and expiration policies
- **CORS**: Cross-Origin Resource Sharing configuration
- **Bucket Policies**: Custom bucket policy support
- **IAM Policies**: Automatic creation of read-only and read-write IAM policies for IRSA
- **Tags**: Automatic Facets tagging plus custom tags

## Usage Examples

### Creating a New Bucket

```yaml
kind: s3_bucket
flavor: standard
version: "1.0"
metadata:
  name: my-application-data
spec:
  # Encryption (enabled by default)
  encryption_enabled: true
  bucket_key_enabled: true

  # Versioning
  versioning_enabled: true

  # Lifecycle rules
  lifecycle_rules:
    - id: archive-old-data
      enabled: true
      transitions:
        - days: 90
          storage_class: STANDARD_IA
        - days: 180
          storage_class: GLACIER
      expiration_days: 365
      abort_incomplete_multipart_days: 7

  # CORS for web access
  cors_rules:
    - allowed_origins:
        - https://example.com
      allowed_methods:
        - GET
        - PUT
        - POST
      allowed_headers:
        - "*"
      max_age_seconds: 3600

  tags:
    application: myapp
    cost_center: engineering
```

### Importing an Existing Bucket

For existing buckets that need to be brought under Facets management:

```yaml
kind: s3_bucket
flavor: standard
version: "1.0"
metadata:
  name: existing-bucket
spec:
  import_existing: true  # CRITICAL: Import existing bucket
  imports:
    bucket_name: my-existing-bucket-name
    bucket_arn: arn:aws:s3:::my-existing-bucket-name

  # Configure management settings (optional)
  encryption_enabled: true
  versioning_enabled: false

  # Add lifecycle rules to manage costs
  lifecycle_rules:
    - id: cleanup-old-uploads
      enabled: true
      abort_incomplete_multipart_days: 7
```

### Bucket with KMS Encryption

```yaml
spec:
  encryption_enabled: true
  kms_key_id: arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012
  bucket_key_enabled: true
```

### Bucket with Custom Policy

```yaml
spec:
  # Allow public read access
  block_public_acls: false
  block_public_policy: false
  ignore_public_acls: false
  restrict_public_buckets: false

  bucket_policy_json: |
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Sid": "PublicReadGetObject",
          "Effect": "Allow",
          "Principal": "*",
          "Action": "s3:GetObject",
          "Resource": "arn:aws:s3:::bucket-name/*"
        }
      ]
    }
```

## Import Mode Details

When `import_existing: true`:

1. Terraform will **import** the existing bucket instead of creating a new one
2. The bucket must already exist in AWS
3. You must provide the bucket name in the `imports` section
4. Terraform will manage the bucket configuration going forward
5. No disruption to existing data or access patterns
6. You can gradually add configuration (lifecycle, CORS, etc.) after import

**Use Cases for Import Mode**:
- Migrating existing buckets to Facets management
- Taking over buckets created manually or via other tools
- Adding Terraform management to legacy infrastructure

## Security Defaults

This module follows AWS S3 security best practices:

- ✅ **Encryption**: Enabled by default (SSE-S3)
- ✅ **Public Access**: All blocked by default
- ✅ **HTTPS**: Enforced through bucket policies (optional)
- ✅ **Versioning**: Available but disabled by default (enable for critical data)
- ✅ **Lifecycle**: Configure to manage costs
- ✅ **IAM Policies**: Auto-generated read-only and read-write policies for IRSA

## Outputs

The module provides outputs compatible with `@facets/s3_bucket`:

**Attributes**:
- `bucket_name` - Bucket ID/name
- `bucket_arn` - Bucket ARN for IAM policies
- `region` - AWS region
- `bucket_domain_name` - S3 domain name
- `bucket_regional_domain_name` - Regional domain name
- `readonly_policy_arn` - IAM policy ARN for read-only access (for IRSA)
- `readwrite_policy_arn` - IAM policy ARN for read-write access (for IRSA)
- `readonly_policy_name` - IAM policy name for read-only access
- `readwrite_policy_name` - IAM policy name for read-write access

**Interfaces**:
- `bucket.name` - Bucket name
- `bucket.arn` - Bucket ARN
- `bucket.region` - AWS region

## IAM Policies for IRSA

The module automatically creates two IAM policies that can be attached to Kubernetes service accounts via IRSA (IAM Roles for Service Accounts):

1. **Read-Only Policy** - Grants:
   - `s3:GetObject`, `s3:GetObjectVersion`
   - `s3:ListBucket`, `s3:ListBucketVersions`
   - `s3:GetBucketLocation`, `s3:GetBucketVersioning`

2. **Read-Write Policy** - Grants all read permissions plus:
   - `s3:PutObject`
   - `s3:DeleteObject`, `s3:DeleteObjectVersion`

These policies can be referenced by other modules (e.g., services) that need S3 access via the output attributes.

## Lifecycle Rule Storage Classes

Available storage classes for transitions:

- `STANDARD_IA` - Infrequent Access (min 30 days)
- `INTELLIGENT_TIERING` - Automatic tiering
- `GLACIER_IR` - Glacier Instant Retrieval (min 90 days)
- `GLACIER` - Glacier Flexible Retrieval (min 90 days)
- `DEEP_ARCHIVE` - Deep Archive (min 180 days)

## Bucket Naming

Bucket names are automatically generated using the pattern: `{instance_name}-{environment-unique-name}`

This ensures:
- Globally unique names across all AWS accounts
- DNS-compliant naming (lowercase, alphanumeric, hyphens)
- Consistent naming convention

## Notes

- Bucket names must be globally unique across all AWS accounts
- Bucket names must be DNS-compliant (lowercase, alphanumeric, hyphens)
- Force destroy should be `false` for production buckets (default)
- Enable versioning for critical data protection
- Use lifecycle rules to optimize storage costs
- Import mode is the safest way to bring existing buckets under management
- IAM policies are automatically created for IRSA integration
