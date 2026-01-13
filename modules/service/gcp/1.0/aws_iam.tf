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
  aws_iam_arns         = lookup(local.aws_cloud_permissions, "iam", {})

  # Get AWS cloud account details (if provided)
  aws_cloud_account = lookup(var.inputs, "aws_cloud_account", null)
  aws_account_id    = local.aws_cloud_account != null ? local.aws_cloud_account.attributes.aws_account_id : null
  aws_region        = local.aws_cloud_account != null ? lookup(local.aws_cloud_account.attributes, "aws_region", "us-east-1") : "us-east-1"
  aws_external_id   = local.aws_cloud_account != null ? lookup(local.aws_cloud_account.attributes, "external_id", null) : null

  # Automatically enable AWS access if IAM ARNs are provided
  enable_aws_access = local.aws_cloud_account != null && length(local.aws_iam_arns) > 0

  # Generate IAM role name
  aws_iam_role_name = "${var.instance_name}-gcp-to-aws"

  # GCP identity for AWS trust policy
  # Format: system:serviceaccount:<namespace>:<k8s-service-account>
  gcp_service_account_identity = "system:serviceaccount:${local.namespace}:${lower(var.instance_name)}"

  # GCP service account email (for tags and reference)
  gcp_service_account_email = "${lower(var.instance_name)}@${local.cluster_project}.iam.gserviceaccount.com"
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
      Name                    = local.aws_iam_role_name
      ManagedBy               = "Facets"
      FacetsService           = var.instance_name
      GCPProject              = local.cluster_project
      GCPServiceAccount       = local.gcp_service_account_email
      KubernetesNamespace     = local.namespace
      KubernetesServiceAccount = lower(var.instance_name)
      Environment             = var.environment.name
      CrossCloudAuth          = "GCP-to-AWS"
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

# ================================================================================
# Outputs
# ================================================================================
# These outputs can be referenced by other modules or used for debugging.

output "aws_iam_role_arn" {
  description = "ARN of the AWS IAM role for cross-cloud access (empty if not enabled)"
  value       = local.enable_aws_access ? aws_iam_role.gcp_workload[0].arn : ""
}

output "aws_iam_role_name" {
  description = "Name of the AWS IAM role for cross-cloud access (empty if not enabled)"
  value       = local.enable_aws_access ? aws_iam_role.gcp_workload[0].name : ""
}

output "aws_env_configuration" {
  description = "Environment variables injected into pods for AWS SDK configuration"
  value       = local.aws_env_vars
  sensitive   = false
}

output "cross_cloud_auth_enabled" {
  description = "Whether AWS cross-cloud authentication is enabled"
  value       = local.enable_aws_access
}

output "aws_attached_policy_arns" {
  description = "List of AWS IAM policy ARNs attached to the role"
  value       = local.enable_aws_access ? [for k, v in local.aws_iam_arns : v.arn] : []
}

# ================================================================================
# Debug Information (for troubleshooting)
# ================================================================================
# Uncomment the output blocks below if you need to debug the configuration

# output "debug_gcp_service_account_identity" {
#   description = "GCP service account identity used in AWS trust policy"
#   value       = local.gcp_service_account_identity
# }

# output "debug_aws_cloud_account_config" {
#   description = "AWS cloud account configuration"
#   value = {
#     account_id  = local.aws_account_id
#     region      = local.aws_region
#     external_id = local.aws_external_id != null ? "***REDACTED***" : null
#   }
# }

# output "debug_aws_iam_arns" {
#   description = "AWS IAM ARNs from spec"
#   value       = local.aws_iam_arns
# }
