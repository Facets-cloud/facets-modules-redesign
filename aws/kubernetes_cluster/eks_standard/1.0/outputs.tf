locals {
  # Output attributes - all non-network outputs
  output_attributes = {
    cluster_id                        = module.eks.cluster_id
    cluster_arn                       = module.eks.cluster_arn
    cluster_name                      = module.eks.cluster_name
    cluster_version                   = module.eks.cluster_version
    cluster_endpoint                  = module.eks.cluster_endpoint
    cluster_ca_certificate            = base64decode(module.eks.cluster_certificate_authority_data)
    cluster_token                     = data.aws_eks_cluster_auth.cluster.token
    cluster_security_group_id         = module.eks.cluster_security_group_id
    node_security_group_id            = module.eks.node_security_group_id
    oidc_provider_arn                 = module.eks.oidc_provider_arn
    cluster_iam_role_arn              = module.eks.cluster_iam_role_arn
    cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id

    # Add secrets marker for sensitive fields
    secrets = ["cluster_token"]
  }

  # Output interfaces - reserved for network endpoints (empty for EKS)
  output_interfaces = {}
}
