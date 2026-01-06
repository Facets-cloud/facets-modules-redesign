# Tag subnets for Karpenter discovery using native AWS provider
# Only create tags when install_karpenter is true (first instance handles tagging)
resource "aws_ec2_tag" "karpenter_subnet_discovery" {
  for_each = local.install_karpenter ? toset(var.inputs.network_details.attributes.private_subnet_ids) : toset([])

  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = local.cluster_name
}

# Tag security group for Karpenter discovery
# Only create tags when install_karpenter is true (first instance handles tagging)
resource "aws_ec2_tag" "karpenter_sg_discovery" {
  count = local.install_karpenter ? 1 : 0

  resource_id = local.node_security_group_id
  key         = "karpenter.sh/discovery"
  value       = local.cluster_name
}
