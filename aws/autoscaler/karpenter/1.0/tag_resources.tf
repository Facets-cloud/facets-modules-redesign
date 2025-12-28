# Tag subnets for Karpenter discovery using native AWS provider
# This is more reliable than local-exec provisioner
resource "aws_ec2_tag" "karpenter_subnet_discovery" {
  for_each = toset(var.inputs.network_details.attributes.private_subnet_ids)

  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = local.cluster_name
}

# Tag security group for Karpenter discovery
resource "aws_ec2_tag" "karpenter_sg_discovery" {
  resource_id = local.node_security_group_id
  key         = "karpenter.sh/discovery"
  value       = local.cluster_name
}
