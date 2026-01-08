locals {
  output_attributes = {
    cluster_endpoint                  = module.eks.cluster_endpoint
    cluster_ca_certificate            = base64decode(module.eks.cluster_certificate_authority_data)
    cluster_name                      = module.eks.cluster_name
    cluster_version                   = module.eks.cluster_version
    cluster_arn                       = module.eks.cluster_arn
    cluster_id                        = module.eks.cluster_id
    oidc_issuer_url                   = module.eks.cluster_oidc_issuer_url
    oidc_provider                     = module.eks.oidc_provider
    oidc_provider_arn                 = module.eks.oidc_provider_arn
    node_iam_role_arn                 = try(module.eks.eks_managed_node_groups_autoscaling_group_names[0], "")
    node_iam_role_name                = try(module.eks.eks_managed_node_groups[0].iam_role_name, "")
    node_security_group_id            = module.eks.node_security_group_id
    cluster_iam_role_arn              = module.eks.cluster_iam_role_arn
    cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
    cluster_security_group_id         = module.eks.cluster_security_group_id
    cloud_provider                    = "AWS"
    kubernetes_provider_exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "bash"
      args        = ["-c", "command -v aws-iam-authenticator >/dev/null 2>&1 || (curl -sLo /tmp/aws-iam-authenticator https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v0.7.8/aws-iam-authenticator_0.7.8_linux_amd64 && chmod +x /tmp/aws-iam-authenticator && mv /tmp/aws-iam-authenticator /usr/local/bin/aws-iam-authenticator); aws-iam-authenticator token -i ${module.eks.cluster_name} --role ${var.inputs.cloud_account.attributes.aws_iam_role} -s facets-k8s-${var.instance_name} -e ${var.inputs.cloud_account.attributes.external_id} --region ${var.inputs.cloud_account.attributes.aws_region}"]
    }
    secrets = ["cluster_ca_certificate", "kubernetes_provider_exec"]
  }
  output_interfaces = {
    kubernetes = {
      host                   = module.eks.cluster_endpoint
      cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
      kubernetes_provider_exec = {
        api_version = "client.authentication.k8s.io/v1beta1"
        command     = "bash"
        args        = ["-c", "command -v aws-iam-authenticator >/dev/null 2>&1 || (curl -sLo /tmp/aws-iam-authenticator https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v0.7.8/aws-iam-authenticator_0.7.8_linux_amd64 && chmod +x /tmp/aws-iam-authenticator && mv /tmp/aws-iam-authenticator /usr/local/bin/aws-iam-authenticator); aws-iam-authenticator token -i ${module.eks.cluster_name} --role ${var.inputs.cloud_account.attributes.aws_iam_role} -s facets-k8s-${var.instance_name} -e ${var.inputs.cloud_account.attributes.external_id} --region ${var.inputs.cloud_account.attributes.aws_region}"]
      }
      secrets = ["cluster_ca_certificate", "kubernetes_provider_exec"]
    }
  }
}
