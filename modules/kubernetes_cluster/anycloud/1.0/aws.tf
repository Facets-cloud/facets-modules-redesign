# AWS branch — EKS cluster (complete: KMS secret encryption, control-plane logging, IRSA/OIDC,
# managed addons, access config). count-gated on the linked account being AWS. Node pools live in
# the separate nodepool module.

# ── Control-plane IAM role ──
resource "aws_iam_role" "eks" {
  count = local.is_aws ? 1 : 0
  name  = "${local.cluster_name}-eks-cluster"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "eks.amazonaws.com" } }]
  })
  tags = local.aws_tags
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  count      = local.is_aws ? 1 : 0
  role       = aws_iam_role.eks[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  count      = local.is_aws ? 1 : 0
  role       = aws_iam_role.eks[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

# ── KMS key for Kubernetes secret envelope encryption ──
resource "aws_kms_key" "eks" {
  count                   = local.is_aws ? 1 : 0
  description             = "EKS secret encryption for ${local.cluster_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = local.aws_tags
}

resource "aws_kms_alias" "eks" {
  count         = local.is_aws ? 1 : 0
  name          = "alias/${local.cluster_name}-eks"
  target_key_id = aws_kms_key.eks[0].key_id
}

# ── Control-plane logging ──
resource "aws_cloudwatch_log_group" "eks" {
  count             = local.is_aws && length(local.aws_log_types) > 0 ? 1 : 0
  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = 90
  tags              = local.aws_tags
}

# ── Cluster ──
resource "aws_eks_cluster" "this" {
  count = local.is_aws ? 1 : 0

  name                      = local.cluster_name
  version                   = local.cluster_version
  role_arn                  = aws_iam_role.eks[0].arn
  enabled_cluster_log_types = local.aws_log_types

  access_config {
    authentication_mode                         = local.aws_auth_mode
    bootstrap_cluster_creator_admin_permissions = local.aws_bootstrap_admin
  }

  vpc_config {
    subnet_ids              = local.eks_subnet_ids
    endpoint_public_access  = local.aws_endpoint_public_access
    endpoint_private_access = local.aws_endpoint_private_access
    public_access_cidrs     = local.aws_endpoint_public_access ? local.aws_public_access_cidrs : null
  }

  # Kubernetes secrets are always envelope-encrypted with this cluster's KMS key.
  encryption_config {
    provider {
      key_arn = aws_kms_key.eks[0].arn
    }
    resources = ["secrets"]
  }

  tags = local.aws_tags

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller,
    aws_cloudwatch_log_group.eks,
  ]
}

# ── IRSA: IAM OIDC provider from the cluster issuer ──
data "tls_certificate" "eks" {
  count = local.is_aws && local.aws_enable_irsa ? 1 : 0
  url   = aws_eks_cluster.this[0].identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  count           = local.is_aws && local.aws_enable_irsa ? 1 : 0
  url             = aws_eks_cluster.this[0].identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks[0].certificates[0].sha1_fingerprint]
  tags            = local.aws_tags
}

# ── EBS CSI driver IRSA role (for the aws-ebs-csi-driver addon) ──
data "aws_iam_policy_document" "ebs_csi_assume" {
  count = local.is_aws && local.aws_enable_irsa && local.aws_addon_ebs_csi ? 1 : 0
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks[0].arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks[0].url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  count              = local.is_aws && local.aws_enable_irsa && local.aws_addon_ebs_csi ? 1 : 0
  name               = "${local.cluster_name}-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume[0].json
  tags               = local.aws_tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  count      = local.is_aws && local.aws_enable_irsa && local.aws_addon_ebs_csi ? 1 : 0
  role       = aws_iam_role.ebs_csi[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# ── Dedicated node security group (distinct from the EKS-managed cluster SG) ──
# Tagged for Karpenter discovery so provisioned nodes attach it. Exposed as node_security_group_id.
resource "aws_security_group" "nodes" {
  count       = local.is_aws ? 1 : 0
  name        = "${local.cluster_name}-nodes"
  description = "EKS worker node security group for ${local.cluster_name}"
  vpc_id      = local.network_id

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.aws_tags, {
    Name                                          = "${local.cluster_name}-nodes"
    "karpenter.sh/discovery"                      = local.cluster_name
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  })

  lifecycle {
    ignore_changes = [tags]
  }
}

# Node <-> node all traffic, and control-plane <-> node.
resource "aws_security_group_rule" "nodes_self" {
  count                    = local.is_aws ? 1 : 0
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.nodes[0].id
  source_security_group_id = aws_security_group.nodes[0].id
  description              = "Node to node"
}

resource "aws_security_group_rule" "nodes_from_cluster" {
  count                    = local.is_aws ? 1 : 0
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.nodes[0].id
  source_security_group_id = aws_eks_cluster.this[0].vpc_config[0].cluster_security_group_id
  description              = "Cluster control plane to nodes"
}

# ── Managed addons ──
resource "aws_eks_addon" "vpc_cni" {
  count                       = local.is_aws && local.aws_addon_vpc_cni ? 1 : 0
  cluster_name                = aws_eks_cluster.this[0].name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = local.aws_tags
}

resource "aws_eks_addon" "kube_proxy" {
  count                       = local.is_aws && local.aws_addon_kubeproxy ? 1 : 0
  cluster_name                = aws_eks_cluster.this[0].name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = local.aws_tags
}

resource "aws_eks_addon" "coredns" {
  count                       = local.is_aws && local.aws_addon_coredns ? 1 : 0
  cluster_name                = aws_eks_cluster.this[0].name
  addon_name                  = "coredns"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = local.aws_tags
}

resource "aws_eks_addon" "ebs_csi" {
  count                       = local.is_aws && local.aws_addon_ebs_csi ? 1 : 0
  cluster_name                = aws_eks_cluster.this[0].name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = local.aws_enable_irsa ? aws_iam_role.ebs_csi[0].arn : null
  tags                        = local.aws_tags
}

resource "aws_eks_addon" "metrics_server" {
  count                       = local.is_aws && local.aws_addon_metrics ? 1 : 0
  cluster_name                = aws_eks_cluster.this[0].name
  addon_name                  = "metrics-server"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = local.aws_tags
}

# ── Default system node group (gated by spec.default_node_pool.enabled on a AWS account) ──
# A small managed node group created WITH the cluster for system workloads. count-gated to 0 when the
# default pool is off, so the cluster is control-plane-only by default.
data "aws_iam_policy_document" "default_node_assume" {
  count = local.aws_default_pool ? 1 : 0
  statement {
    sid     = "EKSNodeAssumeRole"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "default_node" {
  count              = local.aws_default_pool ? 1 : 0
  name               = "${local.cluster_name}-sys-node"
  assume_role_policy = data.aws_iam_policy_document.default_node_assume[0].json
  tags               = local.aws_tags
}

resource "aws_iam_role_policy_attachment" "default_node" {
  for_each = local.aws_default_pool ? toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ]) : toset([])
  policy_arn = each.value
  role       = aws_iam_role.default_node[0].name
}

# Zone pinning (optional): when default_node_pool.aws.availability_zones is set, restrict the system
# node group to the private subnets in those AZs. DescribeSubnets filtering (not a per-id data source)
# keeps count keys static, so it works even when the subnet ids are unknown until apply.
data "aws_subnets" "system_pinned" {
  count = local.aws_default_pool && length(local.dp_aws_pin_azs) > 0 ? 1 : 0
  filter {
    name   = "subnet-id"
    values = local.private_subnet_ids
  }
  filter {
    name   = "availability-zone"
    values = local.dp_aws_pin_azs
  }
}

resource "aws_eks_node_group" "system" {
  count = local.aws_default_pool ? 1 : 0

  cluster_name    = aws_eks_cluster.this[0].name
  node_group_name = "${local.cluster_name}-sys"
  node_role_arn   = aws_iam_role.default_node[0].arn
  subnet_ids      = length(local.dp_aws_pin_azs) > 0 ? data.aws_subnets.system_pinned[0].ids : local.private_subnet_ids
  instance_types  = local.dp_aws_instance_types
  capacity_type   = local.dp_aws_capacity_type
  ami_type        = local.dp_aws_ami_type
  disk_size       = local.dp_aws_disk_size

  labels = {
    "workload-type" = "system"
    "node-role"     = "system"
  }

  scaling_config {
    desired_size = local.dp_aws_desired_size
    min_size     = local.dp_aws_min_size
    max_size     = local.dp_aws_max_size
  }

  update_config {
    max_unavailable = local.dp_aws_max_unavailable
  }

  tags = merge(local.aws_tags, { Name = "${local.cluster_name}-system-node" })

  lifecycle {
    precondition {
      condition     = length(local.dp_aws_pin_azs) == 0 || length(try(data.aws_subnets.system_pinned[0].ids, [])) > 0
      error_message = "default_node_pool.aws.availability_zones pins the system node group to AZ(s) with no matching private subnet. Use AZ names that exist in the VPC."
    }
  }

  # Wait for the node role policies + the vpc-cni addon so nodes join and get pod networking.
  depends_on = [aws_iam_role_policy_attachment.default_node]
}
