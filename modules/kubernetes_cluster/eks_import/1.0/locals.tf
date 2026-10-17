# Import-faithful EKS cluster: every attribute is driven by the live spec (pushed as an env
# override) so a plan against the live cluster is 0-change. See facets.yaml / CLUSTER-IMPORT-SPEC.md.
locals {
  spec = var.instance.spec

  vpc_id = var.inputs.network_details.attributes.vpc_id

  cluster       = local.spec.cluster
  cluster_role  = local.spec.cluster_role
  workers_role  = local.spec.workers_role
  elb_sl_policy = local.spec.elb_sl_policy
  cluster_sg    = local.spec.cluster_sg
  workers_sg    = local.spec.workers_sg
  kms           = local.spec.kms
  oidc          = local.spec.oidc

  # IAM role policy attachments keyed by policy arn (import id = "role_name/policy_arn")
  cluster_policy_arns = { for a in local.spec.cluster_policy_arns : a => a }
  workers_policy_arns = { for a in local.spec.workers_policy_arns : a => a }

  # SG rule fan-out. "sg" selects which security group the rule lives on; "referenced_sg"
  # (optional) selects the source SG for group-to-group rules (or self).
  sg_id = {
    cluster     = aws_security_group.cluster.id
    workers     = aws_security_group.workers.id
    eks_managed = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  }
  sg_rules = { for r in local.spec.sg_rules : r.key => r }

  launch_templates  = local.spec.launch_templates
  asgs              = local.spec.asgs
  instance_profiles = local.spec.instance_profiles
  addons            = local.spec.addons
  key_pair          = local.spec.key_pair
}
