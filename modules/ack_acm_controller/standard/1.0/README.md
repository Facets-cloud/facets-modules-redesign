# ACK ACM Controller

AWS Controllers for Kubernetes (ACK) - ACM Controller for managing AWS Certificate Manager certificates as Kubernetes resources.

## Overview

This module deploys the **ACK ACM Controller** on EKS clusters via Helm. It enables managing AWS Certificate Manager (ACM) certificates using Kubernetes custom resources, allowing certificates to be requested, validated, and exported as Kubernetes TLS secrets for use with Gateway API or Ingress controllers.

### What It Does

- Deploys the ACK ACM controller Helm chart from `oci://public.ecr.aws/aws-controllers-k8s/acm-chart`
- Creates an IAM policy with ACM permissions (request, describe, delete, import, renew certificates)
- Sets up IRSA (IAM Role for Service Account) for secure AWS authentication
- Supports DNS validation via Route53

### IAM Permissions

The controller is granted the following ACM actions on all resources:

| Action | Purpose |
|--------|---------|
| `acm:RequestCertificate` | Request new certificates |
| `acm:DescribeCertificate` | Check certificate status |
| `acm:DeleteCertificate` | Clean up certificates |
| `acm:ImportCertificate` | Import external certificates |
| `acm:RenewCertificate` | Renew existing certificates |
| `acm:GetCertificate` | Retrieve certificate details |
| `acm:ExportCertificate` | Export certificates to K8s secrets |
| `acm:ListCertificates` | List available certificates |
| `acm:*TagsForCertificate` | Manage certificate tags |
| `acm:UpdateCertificateOptions` | Update certificate settings |

---

## Configuration

### Basic Example

```json
{
  "kind": "ack_acm_controller",
  "flavor": "standard",
  "version": "1.0",
  "spec": {
    "chart_version": "1.3.4"
  }
}
```

### Custom Namespace

```json
{
  "kind": "ack_acm_controller",
  "flavor": "standard",
  "version": "1.0",
  "spec": {
    "chart_version": "1.3.4",
    "namespace": "ack-system"
  }
}
```

### Custom Helm Values

```json
{
  "kind": "ack_acm_controller",
  "flavor": "standard",
  "version": "1.0",
  "spec": {
    "chart_version": "1.3.4",
    "helm_values": {
      "resources": {
        "requests": {
          "cpu": "100m",
          "memory": "128Mi"
        },
        "limits": {
          "cpu": "200m",
          "memory": "256Mi"
        }
      }
    }
  }
}
```

---

## Spec Options

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `chart_version` | string | `1.3.4` | Yes | Helm chart version of the ACK ACM Controller |
| `namespace` | string | env namespace | No | Kubernetes namespace for the controller |
| `helm_values` | object | - | No | Additional Helm values to override defaults |

---

## Inputs

| Input | Type | Required | Description |
|-------|------|----------|-------------|
| `cloud_account` | `@facets/aws_cloud_account` | Yes | AWS Cloud Account for IAM and resource provisioning (provides AWS provider) |
| `eks_details` | `@facets/eks` | Yes | EKS cluster (provides Helm and Kubernetes providers) |
| `kubernetes_node_pool_details` | `@facets/kubernetes_nodepool` | No | Node pool for scheduling controller pods |

---

## Outputs

| Output | Description |
|--------|-------------|
| `namespace` | Kubernetes namespace where the controller is deployed |
| `release_name` | Helm release name (`ack-acm-controller`) |
| `chart_version` | Deployed Helm chart version |
| `role_arn` | IAM role ARN used by the controller (IRSA) |
| `helm_release_id` | Helm release ID |

---

## Default Resources

| Resource | CPU Request | Memory Request | CPU Limit | Memory Limit |
|----------|------------|---------------|-----------|-------------|
| Controller | 50m | 64Mi | 100m | 128Mi |

Override via `helm_values.resources` in the spec.

---

## Troubleshooting

### Check Controller Status

```bash
kubectl get pods -n <namespace> -l app.kubernetes.io/name=ack-acm-controller
kubectl logs -n <namespace> -l app.kubernetes.io/name=ack-acm-controller
```

### Verify IRSA

```bash
kubectl get sa ack-acm-controller -n <namespace> -o jsonpath='{.metadata.annotations}'
```

### Check ACM Certificate Resources

```bash
kubectl get certificates.acm.services.k8s.aws -n <namespace>
kubectl describe certificate.acm.services.k8s.aws <cert-name> -n <namespace>
```

---

## Resources

- [ACK ACM Controller Documentation](https://aws-controllers-k8s.github.io/community/docs/community/services/#amazon-certificate-manager-acm)
- [ACK GitHub Repository](https://github.com/aws-controllers-k8s/acm-controller)
- [AWS Certificate Manager Documentation](https://docs.aws.amazon.com/acm/)
