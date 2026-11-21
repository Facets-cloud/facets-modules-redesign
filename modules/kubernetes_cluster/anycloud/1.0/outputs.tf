# Output contracts:
#   default    -> @facets/any_cloud_kubernetes_cluster (attributes + interfaces.aws/.gcp, no providers)
#   attributes -> @facets/kubernetes-details (same output_attributes, carries kubernetes/helm providers)
# Common keys go in attributes; cloud-specific keys go in interfaces.aws / interfaces.gcp.
# The inactive cloud is NULL-KEYED with identical keys, never {}.

locals {
  # Common, cloud-neutral attributes (uniform key, active cloud's value — no coalesce()).
  # The kubernetes/helm providers on the `attributes` output read cluster_endpoint /
  # cluster_ca_certificate / kubernetes_provider_exec from HERE. The first five keys match
  # the @facets/kubernetes-details schema so existing consumers of that type work unchanged.
  output_attributes = {
    cloud_provider           = local.cloud_provider
    cluster_id               = local.is_aws ? local.aws_cluster_id : local.gcp_cluster_id
    cluster_name             = local.cluster_name
    cluster_location         = local.is_aws ? local.aws_region : local.gcp_location
    cluster_endpoint         = local.cluster_endpoint
    region                   = local.is_aws ? local.aws_region : local.gcp_region
    cluster_ca_certificate   = local.cluster_ca_certificate
    kubernetes_provider_exec = local.kubernetes_provider_exec
    cluster_version          = local.cluster_version
    secrets                  = ["kubernetes_provider_exec", "cluster_ca_certificate"]
  }

  # Cloud-specific fields → interfaces. Inactive side null-keyed with the SAME keys.
  output_interfaces = {
    # Same shape as @facets/kubernetes-details interfaces.kubernetes (both clouds).
    kubernetes = {
      host                   = local.cluster_endpoint
      cluster_ca_certificate = local.cluster_ca_certificate
      secrets                = ["cluster_ca_certificate"]
    }

    # EKS internals — IRSA/Karpenter/controllers consume these.
    aws = local.is_aws ? {
      cluster_arn               = try(aws_eks_cluster.this[0].arn, null)
      oidc_issuer_url           = try(aws_eks_cluster.this[0].identity[0].oidc[0].issuer, null)
      oidc_provider             = try(replace(aws_eks_cluster.this[0].identity[0].oidc[0].issuer, "https://", ""), null)
      oidc_provider_arn         = try(aws_iam_openid_connect_provider.eks[0].arn, null)
      node_security_group_id    = try(aws_security_group.nodes[0].id, null)
      cluster_security_group_id = try(aws_eks_cluster.this[0].vpc_config[0].cluster_security_group_id, null)
      } : {
      cluster_arn               = null
      oidc_issuer_url           = null
      oidc_provider             = null
      oidc_provider_arn         = null
      node_security_group_id    = null
      cluster_security_group_id = null
    }
    # GKE specifics — VPC-native ranges, network, project, and the public OIDC issuer
    # (for example, to register the cluster as an IAM OIDC provider in another cloud).
    gcp = local.is_gcp ? {
      project_id          = local.gcp_project
      pods_range_name     = local.gcp_pods_range
      services_range_name = local.gcp_services_range
      network             = local.network_id
      subnetwork          = local.gcp_subnetwork
      oidc_issuer_url     = local.gcp_oidc_issuer
      } : {
      project_id          = null
      pods_range_name     = null
      services_range_name = null
      network             = null
      subnetwork          = null
      oidc_issuer_url     = null
    }
  }
}

