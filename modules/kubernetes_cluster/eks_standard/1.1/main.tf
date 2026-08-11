# eks_standard/1.1 — adapted to adopt the existing saas-dev EKS cluster at zero-change.
# Flat topology (cluster + OIDC + addons), matching the live cluster exactly.
# Provider from input "cloud_account"; network from input "network_details".

locals {
  region       = var.inputs.cloud_account.attributes.aws_region
  cluster_name = "saas-dev-k8s-cluster"

  cluster_role_arn = "arn:aws:iam::590183767672:role/saas-dev-k8s-cluster20240307082211013700000001"
  secrets_kms_arn  = "arn:aws:kms:us-east-2:590183767672:key/a617cd8b-05c0-4bd5-9479-1b3454297fe2"

  cluster_subnet_ids = ["subnet-04f40865feaf51000", "subnet-02ba16a5f416eb3f1"]
  cluster_sg_ids     = ["sg-00609b01f4b23b846"]

  oidc_url        = "https://oidc.eks.us-east-2.amazonaws.com/id/8FB31AB8F909C58CACB4E39907F8EF5E"
  oidc_thumbprint = "06b25927c42a721631c1efd9431e648fa62e1e39"

  addons = {
    "coredns"             = { version = "v1.14.2-eksbuild.4" }
    "kube-proxy"          = { version = "v1.35.3-eksbuild.5" }
    "vpc-cni"             = { version = "v1.21.1-eksbuild.8" }
    "snapshot-controller" = { version = "v8.3.0-eksbuild.1" }
    "aws-efs-csi-driver"  = { version = "v2.1.13-eksbuild.1", role = "arn:aws:iam::590183767672:role/saas-cp-saas-dev-efs-csi-driver-zagnedirjd" }
  }
}

resource "aws_eks_cluster" "this" {
  name                          = local.cluster_name
  role_arn                      = local.cluster_role_arn
  version                       = "1.35"
  bootstrap_self_managed_addons = false

  vpc_config {
    subnet_ids              = local.cluster_subnet_ids
    security_group_ids      = local.cluster_sg_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
  }

  kubernetes_network_config {
    service_ipv4_cidr = "172.20.0.0/16"
    ip_family         = "ipv4"
  }

  access_config {
    authentication_mode = "CONFIG_MAP"
  }

  encryption_config {
    provider {
      key_arn = local.secrets_kms_arn
    }
    resources = ["secrets"]
  }

  lifecycle {
    ignore_changes = [tags, tags_all, bootstrap_self_managed_addons, access_config[0].bootstrap_cluster_creator_admin_permissions]
  }
}

resource "aws_iam_openid_connect_provider" "this" {
  url             = local.oidc_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [local.oidc_thumbprint]
  lifecycle {
    ignore_changes = [tags, tags_all]
  }
}

resource "aws_eks_addon" "this" {
  for_each                 = local.addons
  cluster_name             = aws_eks_cluster.this.name
  addon_name               = each.key
  addon_version            = each.value.version
  service_account_role_arn = lookup(each.value, "role", null)
  lifecycle {
    ignore_changes = [tags, tags_all, configuration_values]
  }
}
