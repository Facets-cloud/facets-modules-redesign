# AWS Cross-Cloud Access for GCP GKE Services

## Overview

This module now supports cross-cloud authentication, enabling services running in GCP GKE to securely access AWS services using IAM role assumption via GCP Workload Identity Federation.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          GCP GKE Cluster                            │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │  Pod (Your Service)                                         │   │
│  │  ┌──────────────────────────────────────────────────────┐  │   │
│  │  │  AWS SDK                                              │  │   │
│  │  │  - Reads AWS_ROLE_ARN env var                        │  │   │
│  │  │  - Reads GCP service account token                   │  │   │
│  │  │  - Calls AWS STS AssumeRoleWithWebIdentity          │  │   │
│  │  └──────────────────────────────────────────────────────┘  │   │
│  │         ↓                                                    │   │
│  │  /var/run/secrets/gcp-service-account/token                │   │
│  │  (GCP Service Account JWT Token)                            │   │
│  └────────────────────────────────────────────────────────────┘   │
│         ↓                                                           │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │  GCP Workload Identity                                      │   │
│  │  Service Account: <service-name>@<project>.iam.gsa         │   │
│  └────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
                    (JWT Token sent to AWS STS)
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│                              AWS                                     │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │  AWS STS (Security Token Service)                           │   │
│  │  - Validates GCP identity token                             │   │
│  │  - Checks trust policy conditions                           │   │
│  │  - Issues temporary AWS credentials                         │   │
│  └────────────────────────────────────────────────────────────┘   │
│         ↓                                                           │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │  IAM Role: <service-name>-gcp-to-aws                        │   │
│  │  Trust Policy: Allows accounts.google.com federation        │   │
│  │  Attached Policies: User-specified IAM policies             │   │
│  └────────────────────────────────────────────────────────────┘   │
│         ↓                                                           │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │  AWS Services (S3, DynamoDB, SQS, etc.)                     │   │
│  │  Accessed using temporary credentials from STS              │   │
│  └────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

## How It Works

### 1. **GCP Side (Workload Identity)**
   - Each service gets a GCP service account via the existing `gcp_workload-identity` module
   - The service account is bound to the Kubernetes service account in the pod
   - GKE automatically mounts a JWT token at `/var/run/secrets/gcp-service-account/token`

### 2. **AWS Side (IAM Role with Trust Policy)**
   - Module creates an AWS IAM role with a trustpolicy that accepts GCP identity tokens
   - Trust policy validates:
     - Token issuer: `accounts.google.com`
     - Token subject: `system:serviceaccount:<namespace>:<service-account-name>`
     - Optional: External ID for additional security
   - IAM policies (S3, DynamoDB, etc.) are attached to this role

### 3. **Token Exchange Flow**
   - Pod's AWS SDK reads the environment variable `AWS_ROLE_ARN`
   - AWS SDK automatically reads the GCP JWT token from `AWS_WEB_IDENTITY_TOKEN_FILE`
   - AWS SDK calls `sts:AssumeRoleWithWebIdentity` with the GCP token
   - AWS STS validates the token and returns temporary AWS credentials
   - AWS SDK uses these credentials to access AWS services

## Configuration

### Prerequisites

1. **AWS Cloud Account Resource** - Add an AWS cloud account to your Facets project
2. **GCP Workload Identity** - Already configured by this module

### facets.yaml Configuration

```yaml
inputs:
  # ... existing inputs ...
  aws_cloud_account:
    type: '@facets/aws_cloud_account'
    displayName: AWS Cloud Account
    optional: true
    providers:
    - aws
```

### Service Spec Configuration

```yaml
kind: service
flavor: gcp
version: '1.0'
spec:
  type: application

  cloud_permissions:
    # GCP permissions (existing)
    gcp:
      roles:
        storage_viewer:
          role: roles/storage.objectViewer

    # NEW: AWS permissions (cross-cloud)
    aws:
      enabled: true
      iam_role_name: my-service-aws-access  # Optional, defaults to <service-name>-gcp-to-aws
      iam_policies:
        s3_read:
          policy_arn: arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
        dynamodb_read:
          policy_arn: arn:aws:iam::123456789012:policy/MyCustomDynamoDBPolicy
```

## Automatic Environment Variables

When AWS access is enabled, the module automatically injects these environment variables into your pod:

| Variable | Value | Purpose |
|----------|-------|---------|
| `AWS_ROLE_ARN` | `arn:aws:iam::123456789012:role/<service-name>-gcp-to-aws` | ARN of the AWS IAM role to assume |
| `AWS_WEB_IDENTITY_TOKEN_FILE` | `/var/run/secrets/gcp-service-account/token` | Path to GCP service account token |
| `AWS_REGION` | `us-east-1` (or from aws_cloud_account) | Default AWS region |
| `AWS_STS_REGIONAL_ENDPOINTS` | `regional` | Use regional STS endpoints |

## Application Code Examples

### Python (boto3)

No code changes required! The AWS SDK automatically uses the environment variables:

```python
import boto3

# This automatically uses the cross-cloud authentication
s3 = boto3.client('s3')
response = s3.list_buckets()
print(response['Buckets'])

# DynamoDB example
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('my-table')
response = table.get_item(Key={'id': '123'})
```

### Node.js (AWS SDK v3)

```javascript
const { S3Client, ListBucketsCommand } = require("@aws-sdk/client-s3");

// SDK automatically reads AWS_ROLE_ARN and AWS_WEB_IDENTITY_TOKEN_FILE
const s3Client = new S3Client({ region: process.env.AWS_REGION });

async function listBuckets() {
  const command = new ListBucketsCommand({});
  const response = await s3Client.send(command);
  console.log(response.Buckets);
}

listBuckets();
```

### Go

```go
package main

import (
    "context"
    "fmt"
    "github.com/aws/aws-sdk-go-v2/config"
    "github.com/aws/aws-sdk-go-v2/service/s3"
)

func main() {
    // SDK automatically uses environment variables
    cfg, err := config.LoadDefaultConfig(context.TODO())
    if err != nil {
        panic(err)
    }

    client := s3.NewFromConfig(cfg)
    result, err := client.ListBuckets(context.TODO(), &s3.ListBucketsInput{})
    if err != nil {
        panic(err)
    }

    for _, bucket := range result.Buckets {
        fmt.Printf("Bucket: %s\n", *bucket.Name)
    }
}
```

### Java (AWS SDK v2)

```java
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.ListBucketsResponse;

public class S3Example {
    public static void main(String[] args) {
        // SDK automatically uses environment variables
        S3Client s3 = S3Client.builder().build();

        ListBucketsResponse response = s3.listBuckets();
        response.buckets().forEach(bucket -> {
            System.out.println("Bucket: " + bucket.name());
        });
    }
}
```

## Security Considerations

### Trust Policy Validation

The AWS IAM role trust policy validates:

1. **Token Issuer**: Must be `accounts.google.com`
2. **Service Account Identity**: Must match `system:serviceaccount:<namespace>:<k8s-service-account>`
3. **Audience Claim**: Validated (wildcard allowed)
4. **Optional External ID**: Additional security layer if configured

### Best Practices

1. **Least Privilege**: Only attach the minimum required IAM policies
2. **Namespace Isolation**: Each namespace gets its own service account
3. **Policy Boundaries**: Consider using IAM permission boundaries for additional control
4. **Monitoring**: Enable AWS CloudTrail to audit role assumption events
5. **Rotation**: GCP tokens are automatically rotated by GKE (short-lived)
6. **External ID**: Use when extra security is needed (configured in aws_cloud_account)

## Debugging

### Check if AWS Access is Enabled

```bash
kubectl get serviceaccount <service-name> -n <namespace> -o yaml
# Look for annotation: eks.amazonaws.com/role-arn
```

### Verify Environment Variables in Pod

```bash
kubectl exec -it <pod-name> -n <namespace> -- env | grep AWS
# Expected output:
# AWS_ROLE_ARN=arn:aws:iam::123456789012:role/my-service-gcp-to-aws
# AWS_WEB_IDENTITY_TOKEN_FILE=/var/run/secrets/gcp-service-account/token
# AWS_REGION=us-east-1
# AWS_STS_REGIONAL_ENDPOINTS=regional
```

### Check GCP Service Account Token

```bash
kubectl exec -it <pod-name> -n <namespace> -- cat /var/run/secrets/gcp-service-account/token
# Should output a JWT token
```

### Test AWS STS Assume Role

```bash
# From inside the pod
aws sts get-caller-identity
# Should show the assumed role identity
```

### Common Issues

#### 1. **"Not authorized to perform sts:AssumeRoleWithWebIdentity"**
   - **Cause**: Trust policy doesn't allow the GCP service account
   - **Fix**: Verify the trust policy includes the correct namespace and service account name

#### 2. **"Token validation failed"**
   - **Cause**: GCP token expired or invalid
   - **Fix**: Check that GKE Workload Identity is properly configured

#### 3. **"Access Denied" when accessing AWS resources**
   - **Cause**: IAM policies don't grant the required permissions
   - **Fix**: Verify the attached IAM policies include the necessary actions

#### 4. **"Could not load credentials"**
   - **Cause**: Environment variables not set or token file not mounted
   - **Fix**: Check that cloud_permissions.aws.enabled = true in the service spec

## Terraform Outputs

The module provides these outputs for reference:

- `aws_iam_role_arn`: ARN of the created AWS IAM role
- `aws_iam_role_name`: Name of the AWS IAM role
- `aws_env_configuration`: Map of environment variables injected into pods
- `cross_cloud_auth_enabled`: Boolean indicating if AWS access is configured

## Limitations

1. **AWS SDK Required**: Your application must use an AWS SDK that supports Web Identity Token authentication
2. **Token Lifetime**: Temporary credentials are valid for 1 hour (AWS default), SDK handles renewal
3. **Single AWS Account**: Each service can only assume roles in one AWS account (the one specified in aws_cloud_account input)
4. **Network Egress**: Ensure your GKE cluster can reach AWS STS endpoints (typically `sts.<region>.amazonaws.com`)

## Migration from Existing Solutions

If you're currently using:

- **Static AWS Credentials**: Remove them from secrets, use this solution instead
- **AWS SDK Credential Rotation**: No longer needed, credentials are automatically rotated
- **Custom Token Exchange**: Remove custom code, AWS SDK handles it automatically

## Cost Considerations

- **AWS STS Calls**: Free (included in AWS account)
- **AWS IAM**: Free (roles and policies)
- **Data Transfer**: Standard AWS data egress charges apply
- **GCP Workload Identity**: Free (included in GKE)

## Support

For issues or questions:
1. Check the debugging section above
2. Review AWS CloudTrail logs for STS assume role events
3. Verify GCP Workload Identity configuration
4. Contact Facets support with the service name and error messages
