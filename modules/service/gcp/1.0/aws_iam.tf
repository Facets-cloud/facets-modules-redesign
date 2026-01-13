# ================================================================================
# AWS IAM Cross-Cloud Authentication
# ================================================================================
# This configuration enables GCP GKE services to access AWS services via:
# 1. GCP Workload Identity (service account in GKE)
# 2. AWS IAM Role with trust policy allowing GCP federation
# 3. AWS IAM Policy ARNs attached to the role
#
# AWS access is automatically enabled when IAM ARNs are provided in the spec.
# ================================================================================

locals {
  # Extract AWS configuration from spec
  aws_cloud_permissions = lookup(lookup(local.spec, "cloud_permissions", {}), "aws", {})
  aws_iam_arns          = lookup(local.aws_cloud_permissions, "iam", {})

  # Get AWS cloud account details (if provided)
  aws_cloud_account = lookup(var.inputs, "aws_cloud_account", null)
  aws_region        = local.aws_cloud_account != null ? lookup(local.aws_cloud_account.attributes, "aws_region", "us-east-1") : "us-east-1"

  # Automatically enable AWS access if IAM ARNs are provided
  enable_aws_access = length(local.aws_iam_arns) > 0

  # Use the same name as the GCP service account from the workload identity module
  # This is fetched from module.gcp-workload-identity[0].name
  aws_iam_role_name = local.enable_aws_access ? module.sr-name.0.name : ""

  # GCP service account email from the workload identity module
  gcp_service_account_email = local.enable_aws_access ? module.gcp-workload-identity[0].gcp_service_account_email : ""

  # GCP identity for AWS trust policy
  # Format: system:serviceaccount:<namespace>:<k8s-service-account>
  gcp_service_account_identity = local.enable_aws_access ? "system:serviceaccount:${module.gcp-workload-identity.0.k8s_service_account_namespace}:${module.gcp-workload-identity.0.k8s_service_account_name}" : ""
}

# ================================================================================
# AWS IAM Role for GCP Workload Identity Federation
# ================================================================================
# This role trusts GCP's OIDC provider (accounts.google.com) and validates
# the specific Kubernetes service account identity from the JWT token.

resource "aws_iam_role" "gcp_workload" {
  count = local.enable_aws_access ? 1 : 0

  name        = local.aws_iam_role_name
  description = "Cross-cloud IAM role for GCP GKE service ${var.instance_name} in ${local.namespace}"

  # Trust policy for GCP Workload Identity Federation
  # AWS STS will validate the GCP-issued JWT token
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          # GCP's identity provider for federation
          Federated = "accounts.google.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            # Validate the token subject claim matches our service account
            "accounts.google.com:sub" = local.gcp_service_account_identity
          }
        }
      }
    ]
  })

  # Maximum session duration for assumed role credentials (1-12 hours)
  # Default is 1 hour, which is appropriate for most use cases
  max_session_duration = 3600

  # Tags for tracking and management
  tags = merge(
    {
      Name                     = local.aws_iam_role_name
      ManagedBy                = "Facets"
      FacetsService            = var.instance_name
      GCPProject               = local.cluster_project
      GCPServiceAccount        = local.gcp_service_account_email
      KubernetesNamespace      = local.namespace
      KubernetesServiceAccount = lower(var.instance_name)
      Environment              = var.environment.name
      CrossCloudAuth           = "GCP-to-AWS"
    },
    lookup(var.environment, "cloud_tags", {})
  )
}

# ================================================================================
# AWS IAM Policy Attachments
# ================================================================================
# Attach the user-specified IAM policy ARNs to the role.
# These can be AWS managed policies or custom policies.

resource "aws_iam_role_policy_attachment" "gcp_workload" {
  for_each = local.enable_aws_access ? local.aws_iam_arns : {}

  role       = aws_iam_role.gcp_workload[0].name
  policy_arn = each.value.arn

  # Ensure the role exists before attaching policies
  depends_on = [aws_iam_role.gcp_workload]
}

# ================================================================================
# Environment Variables for AWS SDK Auto-Configuration
# ================================================================================
# These environment variables are automatically injected into the pod.
# The AWS SDK reads these and handles the Web Identity Federation flow.

locals {
  # Environment variables for AWS SDK
  aws_env_vars = local.enable_aws_access ? {
    # ARN of the AWS IAM role to assume
    AWS_ROLE_ARN = aws_iam_role.gcp_workload[0].arn

    # Path to the GCP service account JWT token (auto-mounted by GKE)
    # The token is used to authenticate with AWS STS
    AWS_WEB_IDENTITY_TOKEN_FILE = "/var/run/secrets/gcp-service-account/token"

    # Default AWS region for API calls
    AWS_REGION = local.aws_region
  } : {}
}
